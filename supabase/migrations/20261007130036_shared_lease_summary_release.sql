-- Explicit applicant handoff; internal drafts remain private. No signing or tenancy authority.
create table public.rental_lease_summary_releases (
 id uuid primary key default gen_random_uuid(),
 draft_id uuid not null unique references public.rental_lease_drafts(id),
 application_id uuid not null references public.rental_applications(id),
 organization_id uuid not null references public.organizations(id),
 released_by uuid not null references auth.users(id), request_id uuid not null,
 draft_version integer not null check(draft_version>0),
 release_reference text not null check(length(release_reference) between 5 and 500),
 created_at timestamptz not null default statement_timestamp(),unique(released_by,request_id)
);
create index rental_lease_summary_application_idx on public.rental_lease_summary_releases(application_id,draft_version desc);
alter table public.rental_lease_summary_releases enable row level security;
revoke all on public.rental_lease_summary_releases from public,anon,authenticated,service_role;
grant select on public.rental_lease_summary_releases to authenticated;
create policy "independent staff read lease summary releases" on public.rental_lease_summary_releases for select to authenticated using(
 organization_id=(select private.verified_enquiry_staff_organization())
 and exists(select 1 from public.rental_lease_drafts d where d.id=draft_id and d.application_id=rental_lease_summary_releases.application_id)
);
create trigger immutable_lease_summary_releases before update or delete on public.rental_lease_summary_releases for each row execute function private.guard_finance_immutable();
create function private.release_rental_lease_summary(p_application_id uuid,p_draft_id uuid,p_expected_version integer,p_request_id uuid,p_release_reference text,p_sharing_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();a public.rental_applications;d public.rental_lease_drafts;r public.rental_lease_summary_releases;verified_email text;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified independent staff required' using errcode='42501';end if;
 if p_application_id is null or p_draft_id is null or p_expected_version is null or p_expected_version<1 or p_expected_version>=2147483647 or p_request_id is null or p_release_reference is null or length(trim(p_release_reference)) not between 5 and 500 or p_sharing_approved is distinct from true then raise exception 'Approved summary release required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 perform 1 from auth.users where id=caller and email_confirmed_at is not null for share;
 if not found or private.verified_enquiry_staff_organization() is distinct from org then raise exception 'Staff authority changed' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,116));
 select * into a from public.rental_applications where id=p_application_id for update;
 if a.id is null or a.organization_id<>org or a.user_id=caller or exists(select 1 from public.application_cosigners where application_id=a.id and recipient_user_id=caller and state='accepted') then raise exception 'Independent organization staff required' using errcode='42501';end if;
 select * into d from public.rental_lease_drafts where id=p_draft_id and application_id=a.id and organization_id=org for share;
 if d.id is null then raise exception 'Draft unavailable' using errcode='42501';end if;
 select * into r from public.rental_lease_summary_releases where released_by=caller and request_id=p_request_id;
 if r.id is not null then
  if r.draft_id<>d.id or r.application_id<>a.id or r.draft_version<>p_expected_version or r.release_reference<>trim(p_release_reference) then raise exception 'Request reference already used' using errcode='22023';end if;
  return jsonb_build_object('id',r.id,'draft_id',d.id,'version',r.draft_version,'state','released');
 end if;
 if d.version<>p_expected_version or d.state<>'prepared' or a.status<>'approved' or d.application_version<>a.version then raise exception 'Approval or draft changed' using errcode='40001';end if;
 if not exists(select 1 from public.rental_unit_reservations where id=d.reservation_id and application_id=a.id and organization_id=org and state='held') then raise exception 'Current held reservation required' using errcode='40001';end if;
 select email into verified_email from auth.users where id=a.user_id and email_confirmed_at is not null for share;
 if verified_email is null or lower(verified_email)<>lower(a.contact_email) or lower(verified_email) is distinct from lower(d.snapshot->'applicant'->>'email') then raise exception 'Verified applicant contact review required' using errcode='22023';end if;
 if exists(select 1 from public.rental_lease_summary_releases where draft_id=d.id) then raise exception 'Summary already released; refresh' using errcode='23505';end if;
 insert into public.rental_lease_summary_releases(draft_id,application_id,organization_id,released_by,request_id,draft_version,release_reference) values(d.id,a.id,org,caller,p_request_id,d.version,trim(p_release_reference)) returning id into created;
 return jsonb_build_object('id',created,'draft_id',d.id,'version',d.version,'state','released');
end $$;
revoke all on function private.release_rental_lease_summary(uuid,uuid,integer,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.release_rental_lease_summary(uuid,uuid,integer,uuid,text,boolean) to authenticated;
create function public.release_rental_lease_summary(p_application_id uuid,p_draft_id uuid,p_expected_version integer,p_request_id uuid,p_release_reference text,p_sharing_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.release_rental_lease_summary(p_application_id,p_draft_id,p_expected_version,p_request_id,p_release_reference,p_sharing_approved);$$;
revoke all on function public.release_rental_lease_summary(uuid,uuid,integer,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.release_rental_lease_summary(uuid,uuid,integer,uuid,text,boolean) to authenticated;
-- Projection avoids internal reasons, references, legal source paths and other participants' contacts.
create function private.applicant_lease_summaries(p_application_id uuid,p_page integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare caller uuid:=auth.uid();total bigint;items jsonb;
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) or not exists(select 1 from public.rental_applications where id=p_application_id and user_id=caller) then raise exception 'Verified applicant required' using errcode='42501';end if;
 if p_page is null or p_page not between 1 and 100000 then raise exception 'Valid history page required' using errcode='22023';end if;
 select count(*) into total from public.rental_lease_summary_releases where application_id=p_application_id;
 select coalesce(jsonb_agg(item order by version desc),'[]'::jsonb) into items from (
  select d.version,jsonb_build_object('id',d.id,'version',d.version,'state',d.state,'starts_on',d.starts_on,'ends_on',d.ends_on,'billing_day',d.billing_day,'rent_minor',d.rent_minor::text,'deposit_minor',d.deposit_minor::text,'property_name',d.snapshot->'property'->>'name','unit_label',d.snapshot->'unit'->>'label','template_title',d.snapshot->'template'->>'title','released_at',r.created_at) as item
  from public.rental_lease_summary_releases r join public.rental_lease_drafts d on d.id=r.draft_id and d.application_id=r.application_id and d.organization_id=r.organization_id
  where r.application_id=p_application_id order by d.version desc limit 25 offset (p_page-1)*25
 ) rows;
 return jsonb_build_object('total',total,'items',items);
end $$;
revoke all on function private.applicant_lease_summaries(uuid,integer) from public,anon,authenticated,service_role;
grant execute on function private.applicant_lease_summaries(uuid,integer) to authenticated;
create function public.applicant_lease_summaries(p_application_id uuid,p_page integer default 1) returns jsonb language sql stable security invoker set search_path='' as $$select private.applicant_lease_summaries(p_application_id,p_page);$$;
revoke all on function public.applicant_lease_summaries(uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.applicant_lease_summaries(uuid,integer) to authenticated;
