-- Signed uploads live for two hours. Wait beyond reservation expiry plus that lifetime.
alter table public.vendor_invoice_evidence_events alter column actor_user_id drop not null;
create table private.invoice_evidence_cleanup_claims(
 evidence_id uuid primary key references public.vendor_invoice_evidence(id),claim_id uuid not null unique,claimed_at timestamptz not null
);
alter table private.invoice_evidence_cleanup_claims enable row level security;
revoke all on private.invoice_evidence_cleanup_claims from public,anon,authenticated,service_role;
create index vendor_invoice_evidence_cleanup_idx on public.vendor_invoice_evidence(organization_id,expires_at,id) where purged_at is null and state in('reserved','expired','withdrawn');

create function private.claim_expired_invoice_evidence() returns table(id uuid,object_path text,claim_id uuid)
language plpgsql security definer set search_path='' as $$
declare org uuid;doc public.vendor_invoice_evidence;nonce uuid;claimed integer:=0;
begin
 for org in select distinct e.organization_id from public.vendor_invoice_evidence e
  where e.purged_at is null and e.state in('reserved','expired','withdrawn') and e.expires_at+interval '2 hours 5 minutes'<statement_timestamp()
  and not exists(select 1 from public.vendor_invoice_review_evidence r where r.evidence_id=e.id)
  and not exists(select 1 from private.invoice_evidence_cleanup_claims c where c.evidence_id=e.id and c.claimed_at>statement_timestamp()-interval '5 minutes')
  order by e.organization_id limit 20 loop
  -- Take the organization lock before evidence rows, matching invoice editing lock order.
  if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119)) then continue;end if;
  for doc in select e.* from public.vendor_invoice_evidence e where e.organization_id=org and e.purged_at is null
   and e.state in('reserved','expired','withdrawn') and e.expires_at+interval '2 hours 5 minutes'<statement_timestamp()
   and not exists(select 1 from public.vendor_invoice_review_evidence r where r.evidence_id=e.id)
   and not exists(select 1 from private.invoice_evidence_cleanup_claims c where c.evidence_id=e.id and c.claimed_at>statement_timestamp()-interval '5 minutes')
   order by e.expires_at,e.id limit (20-claimed) for update of e skip locked loop
   nonce:=gen_random_uuid();
   insert into private.invoice_evidence_cleanup_claims(evidence_id,claim_id,claimed_at) values(doc.id,nonce,statement_timestamp())
    on conflict(evidence_id) do update set claim_id=excluded.claim_id,claimed_at=excluded.claimed_at;
   if doc.state='reserved' then
    update public.vendor_invoice_evidence e set state='expired' where e.id=doc.id;
    insert into public.vendor_invoice_evidence_events(evidence_id,actor_user_id,event_name) values(doc.id,null,'expired');
   end if;
   id:=doc.id;object_path:=doc.object_path;claim_id:=nonce;claimed:=claimed+1;return next;
  end loop;
  if claimed>=20 then exit;end if;
 end loop;
end $$;
revoke all on function private.claim_expired_invoice_evidence() from public,anon,authenticated,service_role;
grant execute on function private.claim_expired_invoice_evidence() to service_role;
create function public.claim_expired_invoice_evidence() returns table(id uuid,object_path text,claim_id uuid)
language sql security invoker set search_path='' as $$select * from private.claim_expired_invoice_evidence();$$;
revoke all on function public.claim_expired_invoice_evidence() from public,anon,authenticated,service_role;
grant execute on function public.claim_expired_invoice_evidence() to service_role;

create function private.mark_invoice_evidence_purged(p_evidence_id uuid,p_claim_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare doc public.vendor_invoice_evidence;claim private.invoice_evidence_cleanup_claims;
begin
 select * into doc from public.vendor_invoice_evidence where id=p_evidence_id;
 if doc.id is null then raise exception 'Evidence cleanup unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(doc.organization_id::text,119));
 select * into doc from public.vendor_invoice_evidence where id=p_evidence_id for update;
 select * into claim from private.invoice_evidence_cleanup_claims where evidence_id=doc.id;
 if claim.claim_id is distinct from p_claim_id or p_claim_id is null then raise exception 'Current cleanup claim required' using errcode='42501';end if;
 if doc.state not in('expired','withdrawn') or exists(select 1 from public.vendor_invoice_review_evidence where evidence_id=doc.id) then raise exception 'Reviewed or current evidence cannot be purged' using errcode='23505';end if;
 if doc.purged_at is not null then return true;end if;
 if claim.claimed_at<=statement_timestamp()-interval '5 minutes' or doc.expires_at+interval '2 hours 5 minutes'>=statement_timestamp() then raise exception 'Cleanup claim expired or upload grace period active' using errcode='23505';end if;
 if exists(select 1 from storage.objects where bucket_id='vendor-invoice-evidence' and name=doc.object_path) then raise exception 'Remove the object through Storage before marking purged' using errcode='23505';end if;
 update public.vendor_invoice_evidence set purged_at=statement_timestamp() where id=doc.id;return true;
end $$;
revoke all on function private.mark_invoice_evidence_purged(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function private.mark_invoice_evidence_purged(uuid,uuid) to service_role;
create function public.mark_invoice_evidence_purged(p_evidence_id uuid,p_claim_id uuid) returns boolean
language sql security invoker set search_path='' as $$select private.mark_invoice_evidence_purged(p_evidence_id,p_claim_id);$$;
revoke all on function public.mark_invoice_evidence_purged(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.mark_invoice_evidence_purged(uuid,uuid) to service_role;
