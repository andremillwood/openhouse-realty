-- Immutable staff intent awaiting an approved signing provider. This record grants no signing or tenancy authority.
create table public.rental_lease_signing_requests (
 id uuid primary key default gen_random_uuid(),
 draft_id uuid not null unique references public.rental_lease_drafts(id),
 application_id uuid not null references public.rental_applications(id),
 organization_id uuid not null references public.organizations(id),
 requested_by uuid not null references auth.users(id), request_id uuid not null,
 draft_version integer not null check(draft_version>0),
 state text not null default 'awaiting_provider' check(state='awaiting_provider'),
 approval_reference text not null check(length(approval_reference) between 5 and 500),
 created_at timestamptz not null default statement_timestamp(),unique(requested_by,request_id)
);
create index rental_lease_signing_application_idx on public.rental_lease_signing_requests(application_id,draft_version desc);
alter table public.rental_lease_signing_requests enable row level security;
revoke all on public.rental_lease_signing_requests from public,anon,authenticated,service_role;
grant select on public.rental_lease_signing_requests to authenticated;
create policy "independent staff read lease signing requests" on public.rental_lease_signing_requests for select to authenticated using(
 organization_id=(select private.verified_enquiry_staff_organization())
 and exists(select 1 from public.rental_applications a where a.id=rental_lease_signing_requests.application_id and a.user_id<>(select auth.uid()))
 and not exists(select 1 from public.application_cosigners c where c.application_id=rental_lease_signing_requests.application_id and c.recipient_user_id=(select auth.uid()) and c.state='accepted')
);
create trigger immutable_lease_signing_requests before update or delete on public.rental_lease_signing_requests for each row execute function private.guard_finance_immutable();
create function private.request_rental_lease_signing(p_application_id uuid,p_draft_id uuid,p_expected_version integer,p_request_id uuid,p_approval_reference text,p_signing_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();a public.rental_applications;d public.rental_lease_drafts;r public.rental_lease_signing_requests;verified_email text;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified independent staff required' using errcode='42501';end if;
 if p_application_id is null or p_draft_id is null or p_expected_version is null or p_expected_version<1 or p_expected_version>=2147483647 or p_request_id is null or p_approval_reference is null or length(trim(p_approval_reference)) not between 5 and 500 or p_signing_approved is distinct from true then raise exception 'Approved signing request required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 perform 1 from auth.users where id=caller and email_confirmed_at is not null for share;
 if not found or private.verified_enquiry_staff_organization() is distinct from org then raise exception 'Staff authority changed' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,116));
 select * into a from public.rental_applications where id=p_application_id for update;
 if a.id is null or a.organization_id<>org or a.user_id=caller or exists(select 1 from public.application_cosigners where application_id=a.id and recipient_user_id=caller and state='accepted') then raise exception 'Independent organization staff required' using errcode='42501';end if;
 select * into d from public.rental_lease_drafts where id=p_draft_id and application_id=a.id and organization_id=org for share;
 if d.id is null then raise exception 'Draft unavailable' using errcode='42501';end if;
 select * into r from public.rental_lease_signing_requests where requested_by=caller and request_id=p_request_id;
 if r.id is not null then
  if r.draft_id<>d.id or r.application_id<>a.id or r.draft_version<>p_expected_version or r.approval_reference<>trim(p_approval_reference) then raise exception 'Request reference already used' using errcode='22023';end if;
  return jsonb_build_object('id',r.id,'draft_id',d.id,'version',r.draft_version,'state','awaiting_provider');
 end if;
 if d.version<>p_expected_version or d.state<>'prepared' or a.status<>'approved' or d.application_version<>a.version then raise exception 'Approval or draft changed' using errcode='40001';end if;
 if not exists(select 1 from public.rental_unit_reservations where id=d.reservation_id and application_id=a.id and organization_id=org and state='held') then raise exception 'Current held reservation required' using errcode='40001';end if;
 select email into verified_email from auth.users where id=a.user_id and email_confirmed_at is not null for share;
 if verified_email is null or lower(verified_email)<>lower(a.contact_email) or lower(verified_email) is distinct from lower(d.snapshot->'applicant'->>'email') then raise exception 'Verified applicant contact review required' using errcode='22023';end if;
 -- Serialize participant consent changes using the application lock used by invitation RPCs.
 if exists(select 1 from pg_catalog.jsonb_array_elements(d.snapshot->'cosigners') participant where not exists(
  select 1 from public.application_cosigners c join auth.users u on u.id=c.recipient_user_id
  where c.id=(participant->>'invitation_id')::uuid and c.application_id=a.id and c.state='accepted'
   and c.version=(participant->>'invitation_version')::integer and c.consent_version=1
   and u.email_confirmed_at is not null and lower(u.email)=lower(participant->>'email')
 )) then raise exception 'Approved co-signer consent or contact changed' using errcode='40001';end if;
 if (select count(*) from public.application_cosigners where application_id=a.id and state='accepted')<>pg_catalog.jsonb_array_length(d.snapshot->'cosigners') then raise exception 'Signing parties changed' using errcode='40001';end if;
 if d.starts_on<(now() at time zone 'America/Jamaica')::date then raise exception 'Lease start needs current approval' using errcode='40001';end if;
 if exists(select 1 from public.rental_lease_signing_requests where draft_id=d.id) then raise exception 'Signing already requested; refresh' using errcode='23505';end if;
 insert into public.rental_lease_signing_requests(draft_id,application_id,organization_id,requested_by,request_id,draft_version,approval_reference) values(d.id,a.id,org,caller,p_request_id,d.version,trim(p_approval_reference)) returning id into created;
 return jsonb_build_object('id',created,'draft_id',d.id,'version',d.version,'state','awaiting_provider');
end $$;
revoke all on function private.request_rental_lease_signing(uuid,uuid,integer,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.request_rental_lease_signing(uuid,uuid,integer,uuid,text,boolean) to authenticated;
create function public.request_rental_lease_signing(p_application_id uuid,p_draft_id uuid,p_expected_version integer,p_request_id uuid,p_approval_reference text,p_signing_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.request_rental_lease_signing(p_application_id,p_draft_id,p_expected_version,p_request_id,p_approval_reference,p_signing_approved);$$;
revoke all on function public.request_rental_lease_signing(uuid,uuid,integer,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.request_rental_lease_signing(uuid,uuid,integer,uuid,text,boolean) to authenticated;
