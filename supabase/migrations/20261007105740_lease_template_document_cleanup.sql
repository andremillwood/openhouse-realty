-- Signed uploads live for two hours. Wait beyond reservation expiry plus that lifetime.
create table private.lease_template_document_cleanup_claims(
 document_id uuid primary key references public.lease_template_documents(id),claim_id uuid not null unique,claimed_at timestamptz not null
);
alter table private.lease_template_document_cleanup_claims enable row level security;
revoke all on private.lease_template_document_cleanup_claims from public,anon,authenticated,service_role;
create index lease_template_documents_cleanup_idx on public.lease_template_documents(organization_id,expires_at,id) where purged_at is null and state in('reserved','expired','withdrawn');

create function private.claim_expired_lease_template_document() returns table(id uuid,object_path text,claim_id uuid)
language plpgsql security definer set search_path='' as $$
declare org uuid;doc public.lease_template_documents;nonce uuid;claimed integer:=0;
begin
 for org in select distinct e.organization_id from public.lease_template_documents e
  where e.purged_at is null and e.state in('reserved','expired','withdrawn') and e.expires_at+interval '2 hours 5 minutes'<statement_timestamp()
  and not exists(select 1 from private.lease_template_document_cleanup_claims c where c.document_id=e.id and c.claimed_at>statement_timestamp()-interval '5 minutes')
  order by e.organization_id limit 20 loop
  -- Take the organization lock before document rows, matching legal upload lock order.
  if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119)) then continue;end if;
  for doc in select e.* from public.lease_template_documents e where e.organization_id=org and e.purged_at is null
   and e.state in('reserved','expired','withdrawn') and e.expires_at+interval '2 hours 5 minutes'<statement_timestamp()
    and not exists(select 1 from private.lease_template_document_cleanup_claims c where c.document_id=e.id and c.claimed_at>statement_timestamp()-interval '5 minutes')
   order by e.expires_at,e.id limit (20-claimed) for update of e skip locked loop
   nonce:=gen_random_uuid();
   insert into private.lease_template_document_cleanup_claims(document_id,claim_id,claimed_at) values(doc.id,nonce,statement_timestamp())
    on conflict(document_id) do update set claim_id=excluded.claim_id,claimed_at=excluded.claimed_at;
   if doc.state='reserved' then
    update public.lease_template_documents e set state='expired' where e.id=doc.id;
    insert into public.lease_template_document_events(document_id,actor_user_id,event_name) values(doc.id,null,'expired');
   end if;
   id:=doc.id;object_path:=doc.object_path;claim_id:=nonce;claimed:=claimed+1;return next;
  end loop;
  if claimed>=20 then exit;end if;
 end loop;
end $$;
revoke all on function private.claim_expired_lease_template_document() from public,anon,authenticated,service_role;
grant execute on function private.claim_expired_lease_template_document() to service_role;
create function public.claim_expired_lease_template_document() returns table(id uuid,object_path text,claim_id uuid)
language sql security invoker set search_path='' as $$select * from private.claim_expired_lease_template_document();$$;
revoke all on function public.claim_expired_lease_template_document() from public,anon,authenticated,service_role;
grant execute on function public.claim_expired_lease_template_document() to service_role;

create function private.mark_lease_template_document_purged(p_document_id uuid,p_claim_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare doc public.lease_template_documents;claim private.lease_template_document_cleanup_claims;
begin
 select * into doc from public.lease_template_documents where id=p_document_id;
 if doc.id is null then raise exception 'Legal document cleanup unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(doc.organization_id::text,119));
 select * into doc from public.lease_template_documents where id=p_document_id for update;
 select * into claim from private.lease_template_document_cleanup_claims where document_id=doc.id;
 if claim.claim_id is distinct from p_claim_id or p_claim_id is null then raise exception 'Current cleanup claim required' using errcode='42501';end if;
 if doc.state not in('expired','withdrawn') then raise exception 'Certified or current legal documents cannot be purged' using errcode='23505';end if;
 if doc.purged_at is not null then return true;end if;
 if claim.claimed_at<=statement_timestamp()-interval '5 minutes' or doc.expires_at+interval '2 hours 5 minutes'>=statement_timestamp() then raise exception 'Cleanup claim expired or upload grace period active' using errcode='23505';end if;
 if exists(select 1 from storage.objects where bucket_id='lease-template-documents' and name=doc.object_path) then raise exception 'Remove the object through Storage before marking purged' using errcode='23505';end if;
 update public.lease_template_documents set purged_at=statement_timestamp() where id=doc.id;return true;
end $$;
revoke all on function private.mark_lease_template_document_purged(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function private.mark_lease_template_document_purged(uuid,uuid) to service_role;
create function public.mark_lease_template_document_purged(p_document_id uuid,p_claim_id uuid) returns boolean
language sql security invoker set search_path='' as $$select private.mark_lease_template_document_purged(p_document_id,p_claim_id);$$;
revoke all on function public.mark_lease_template_document_purged(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.mark_lease_template_document_purged(uuid,uuid) to service_role;
