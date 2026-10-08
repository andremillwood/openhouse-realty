-- Withdrawal preserves the immutable approval; provider dispatch must exclude withdrawn intents.
create table public.rental_lease_signing_withdrawals(
 id uuid primary key default gen_random_uuid(),signing_id uuid not null unique references public.rental_lease_signing_requests(id),
 organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,
 reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default statement_timestamp(),unique(actor_user_id,request_id)
);
alter table public.rental_lease_signing_withdrawals enable row level security;
revoke all on public.rental_lease_signing_withdrawals from public,anon,authenticated,service_role;
grant select on public.rental_lease_signing_withdrawals to authenticated;
create policy "independent staff read signing withdrawals" on public.rental_lease_signing_withdrawals for select to authenticated using(
 organization_id=(select private.verified_enquiry_staff_organization()) and exists(select 1 from public.rental_lease_signing_requests r where r.id=signing_id and r.organization_id=rental_lease_signing_withdrawals.organization_id)
);
create trigger immutable_signing_withdrawals before update or delete on public.rental_lease_signing_withdrawals for each row execute function private.guard_finance_immutable();
create function private.withdraw_rental_lease_signing(p_signing_id uuid,p_request_id uuid,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();r public.rental_lease_signing_requests;a public.rental_applications;w public.rental_lease_signing_withdrawals;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified independent staff required' using errcode='42501';end if;
 if p_signing_id is null or p_request_id is null or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Approved explained withdrawal required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 perform 1 from auth.users where id=caller and email_confirmed_at is not null for share;
 if not found or private.verified_enquiry_staff_organization() is distinct from org then raise exception 'Staff authority changed' using errcode='42501';end if;
 select * into r from public.rental_lease_signing_requests where id=p_signing_id and organization_id=org;
 if r.id is null then raise exception 'Organization signing request required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,116));
 select * into a from public.rental_applications where id=r.application_id for update;
 if a.id is null or a.organization_id<>org or a.user_id=caller or exists(select 1 from public.application_cosigners where application_id=a.id and recipient_user_id=caller and state='accepted') then raise exception 'Independent staff required' using errcode='42501';end if;
 select * into r from public.rental_lease_signing_requests where id=p_signing_id for update;
 select * into w from public.rental_lease_signing_withdrawals where actor_user_id=caller and request_id=p_request_id;
 if w.id is not null then
  if w.signing_id<>r.id or w.organization_id<>org or w.reason<>trim(p_reason) then raise exception 'Request reference already used' using errcode='22023';end if;
  return jsonb_build_object('id',w.id,'signing_id',r.id,'state','withdrawn');
 end if;
 if r.state<>'awaiting_provider' then raise exception 'Provider cancellation is required' using errcode='40001';end if;
 if exists(select 1 from public.rental_lease_signing_withdrawals where signing_id=r.id) then raise exception 'Signing request already withdrawn' using errcode='23505';end if;
 insert into public.rental_lease_signing_withdrawals(signing_id,organization_id,actor_user_id,request_id,reason) values(r.id,org,caller,p_request_id,trim(p_reason)) returning id into created;
 return jsonb_build_object('id',created,'signing_id',r.id,'state','withdrawn');
end $$;
revoke all on function private.withdraw_rental_lease_signing(uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.withdraw_rental_lease_signing(uuid,uuid,text,boolean) to authenticated;
create function public.withdraw_rental_lease_signing(p_signing_id uuid,p_request_id uuid,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.withdraw_rental_lease_signing(p_signing_id,p_request_id,p_reason,p_approved);$$;
revoke all on function public.withdraw_rental_lease_signing(uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.withdraw_rental_lease_signing(uuid,uuid,text,boolean) to authenticated;
