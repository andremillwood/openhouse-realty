-- Private staff preparation snapshots. No signature/tenancy authority is granted.
create view public.current_approved_lease_templates with(security_invoker=true) as select distinct on(organization_id,template_key) id,organization_id,template_key,version,title from public.approved_lease_templates order by organization_id,template_key,version desc;
revoke all on public.current_approved_lease_templates from public,anon,authenticated;
grant select on public.current_approved_lease_templates to authenticated,service_role;
create table public.rental_lease_drafts (
 id uuid primary key default gen_random_uuid(),application_id uuid not null references public.rental_applications(id),organization_id uuid not null references public.organizations(id),
 approval_id uuid not null references public.rental_approval_decisions(id),reservation_id uuid not null references public.rental_unit_reservations(id),template_id uuid not null references public.approved_lease_templates(id),
 application_version integer not null,version integer not null check(version>0),state text not null default 'prepared' check(state in('prepared','superseded','voided')),
 starts_on date not null,ends_on date not null check(ends_on>starts_on),billing_day integer not null check(billing_day between 1 and 31),
 rent_minor bigint not null check(rent_minor>0),deposit_minor bigint not null check(deposit_minor between 0 and 99999999999999),
 terms_reference text not null check(length(terms_reference) between 5 and 500),snapshot jsonb not null,
 prepared_by uuid not null references auth.users(id),request_id uuid not null,created_at timestamptz not null default now(),closed_at timestamptz,closed_reason text,
 unique(application_id,version),unique(prepared_by,request_id)
);
create unique index rental_lease_drafts_current_idx on public.rental_lease_drafts(application_id) where state='prepared';
create index rental_lease_drafts_org_idx on public.rental_lease_drafts(organization_id,created_at desc);
alter table public.rental_lease_drafts enable row level security;
revoke all on public.rental_lease_drafts from public,anon,authenticated;
grant select on public.rental_lease_drafts to authenticated;
grant select,insert,update on public.rental_lease_drafts to service_role;
create policy "independent verified staff read organization lease drafts" on public.rental_lease_drafts for select to authenticated using(
 organization_id=(select private.verified_enquiry_staff_organization()) and exists(select 1 from public.rental_applications a where a.id=application_id and a.user_id<>(select auth.uid()))
 and not exists(select 1 from public.application_cosigners c where c.application_id=rental_lease_drafts.application_id and c.recipient_user_id=(select auth.uid()) and c.state='accepted')
);
create function private.prepare_rental_lease_draft(p_application_id uuid,p_request_id uuid,p_expected_application_version integer,p_expected_draft_version integer,p_template_id uuid,p_template_version integer,p_starts_on date,p_ends_on date,p_billing_day integer,p_deposit_minor bigint,p_approval_reference text,p_terms_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();application public.rental_applications;reservation public.rental_unit_reservations;decision public.rental_approval_decisions;template public.approved_lease_templates;existing public.rental_lease_drafts;current_version integer;created uuid;unit public.units;property public.properties;applicant_email text;cosigners jsonb;frozen jsonb;
begin
 if org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_request_id is null or p_template_id is null or p_expected_application_version is null or p_expected_application_version<1 or p_expected_application_version>=2147483647 or p_expected_draft_version is null or p_expected_draft_version<0 or p_expected_draft_version>=2147483647 or p_template_version is null or p_template_version<1 or p_starts_on is null or p_ends_on is null or p_ends_on<=p_starts_on or p_billing_day is null or p_billing_day not between 1 and 31 or p_deposit_minor is null or p_deposit_minor not between 0 and 99999999999999 or p_approval_reference is null or length(trim(p_approval_reference)) not between 5 and 500 or p_terms_approved is distinct from true then raise exception 'Valid approved draft terms required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,116));
 select * into application from public.rental_applications where id=p_application_id for update;
 if application.id is null or application.organization_id<>org or application.user_id=caller or exists(select 1 from public.application_cosigners where application_id=application.id and recipient_user_id=caller and state='accepted') then raise exception 'Independent organization preparer required' using errcode='42501';end if;
 select * into existing from public.rental_lease_drafts where prepared_by=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.application_id<>application.id or existing.application_version<>p_expected_application_version or existing.version<>p_expected_draft_version+1 or existing.template_id<>p_template_id or existing.starts_on<>p_starts_on or existing.ends_on<>p_ends_on or existing.billing_day<>p_billing_day or existing.deposit_minor<>p_deposit_minor or existing.terms_reference<>trim(p_approval_reference) or not exists(select 1 from public.approved_lease_templates where id=existing.template_id and version=p_template_version) then raise exception 'Request ID already used' using errcode='22023';end if;
  return jsonb_build_object('id',existing.id,'version',existing.version,'state',existing.state);
 end if;
 if application.version<>p_expected_application_version then raise exception 'Application changed; refresh' using errcode='40001';end if;
 if application.status<>'approved' or p_starts_on<(now() at time zone 'America/Jamaica')::date then raise exception 'Current approval and future lease dates required' using errcode='22023';end if;
 select coalesce(max(version),0) into current_version from public.rental_lease_drafts where application_id=application.id;
 if current_version<>p_expected_draft_version then raise exception 'Lease draft changed; refresh' using errcode='40001';end if;
 if (select count(*) from public.rental_lease_drafts where prepared_by=caller and created_at>now()-interval '1 day')>=50 then raise exception 'Daily draft limit reached' using errcode='22023';end if;
 select * into template from public.approved_lease_templates where id=p_template_id and organization_id=org;
 if template.id is null then raise exception 'Approved organization template required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock_shared(pg_catalog.hashtextextended(org::text||':'||template.template_key,117));
 if template.version<>p_template_version or template.version<>(select max(version) from public.approved_lease_templates where organization_id=org and template_key=template.template_key) then raise exception 'Template changed; select the current approved version' using errcode='40001';end if;
 select * into reservation from public.rental_unit_reservations where application_id=application.id and state='held' for update;
 select * into decision from public.rental_approval_decisions where id=reservation.decision_id;
 if reservation.id is null or reservation.organization_id<>org or decision.application_version<>application.version then raise exception 'Current approval reservation required' using errcode='22023';end if;
 select * into unit from public.units where id=reservation.unit_id for update;
 select * into property from public.properties where id=unit.property_id;
 if unit.id is null or property.organization_id is distinct from org or not exists(select 1 from public.listings where id=reservation.listing_id and organization_id=org and unit_id=unit.id and property_id=property.id and intent='rent') then raise exception 'Reserved unit linkage unavailable' using errcode='22023';end if;
 select email into applicant_email from auth.users where id=application.user_id and email_confirmed_at is not null;
 if applicant_email is null or lower(applicant_email)<>lower(application.contact_email) then raise exception 'Applicant contact changed; verified contact review required' using errcode='22023';end if;
 if exists(select 1 from pg_catalog.jsonb_array_elements(decision.cosigner_snapshot) s where not exists(select 1 from public.application_cosigners c join auth.users u on u.id=c.recipient_user_id where c.id=(s->>'cosigner_id')::uuid and c.application_id=application.id and c.state='accepted' and c.version=(s->>'version')::integer and c.consent_version=1 and u.email_confirmed_at is not null and lower(u.email)=lower(c.invite_email))) then raise exception 'Approved co-signer consent or contact changed' using errcode='22023';end if;
 select coalesce(jsonb_agg(jsonb_build_object('invitation_id',c.id,'user_id',c.recipient_user_id,'email',u.email,'consent_version',c.consent_version,'invitation_version',c.version,'consented_at',c.consented_at) order by c.id),'[]'::jsonb) into cosigners from public.application_cosigners c join auth.users u on u.id=c.recipient_user_id where c.application_id=application.id and c.state='accepted';
 frozen:=jsonb_build_object('applicant',jsonb_build_object('user_id',application.user_id,'name',application.contact_name,'email',applicant_email),'cosigners',cosigners,'managing_organization',jsonb_build_object('id',org,'name',(select name from public.organizations where id=org)),'property',jsonb_build_object('id',property.id,'name',property.name,'address',property.address_text,'area',property.area,'revision',property.management_revision),'unit',jsonb_build_object('id',unit.id,'label',unit.unit_label,'revision',unit.management_revision),'listing',jsonb_build_object('id',application.listing_id,'title',application.title_snapshot),'template',jsonb_build_object('id',template.id,'key',template.template_key,'version',template.version,'title',template.title,'source_reference',template.source_reference,'sha256',template.content_sha256),'approval_id',decision.id);
 update public.rental_lease_drafts set state='superseded',closed_at=now(),closed_reason='Replaced by draft version '||(current_version+1)::text where application_id=application.id and state='prepared';
 insert into public.rental_lease_drafts(application_id,organization_id,approval_id,reservation_id,template_id,application_version,version,starts_on,ends_on,billing_day,rent_minor,deposit_minor,terms_reference,snapshot,prepared_by,request_id) values(application.id,org,decision.id,reservation.id,template.id,application.version,current_version+1,p_starts_on,p_ends_on,p_billing_day,(application.rent_jmd_snapshot*100)::bigint,p_deposit_minor,trim(p_approval_reference),frozen,caller,p_request_id) returning id into created;
 return jsonb_build_object('id',created,'version',current_version+1,'state','prepared');
end $$;
revoke all on function private.prepare_rental_lease_draft(uuid,uuid,integer,integer,uuid,integer,date,date,integer,bigint,text,boolean) from public,anon;
grant execute on function private.prepare_rental_lease_draft(uuid,uuid,integer,integer,uuid,integer,date,date,integer,bigint,text,boolean) to authenticated;
create function public.prepare_rental_lease_draft(p_application_id uuid,p_request_id uuid,p_expected_application_version integer,p_expected_draft_version integer,p_template_id uuid,p_template_version integer,p_starts_on date,p_ends_on date,p_billing_day integer,p_deposit_minor bigint,p_approval_reference text,p_terms_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.prepare_rental_lease_draft(p_application_id,p_request_id,p_expected_application_version,p_expected_draft_version,p_template_id,p_template_version,p_starts_on,p_ends_on,p_billing_day,p_deposit_minor,p_approval_reference,p_terms_approved);$$;
revoke all on function public.prepare_rental_lease_draft(uuid,uuid,integer,integer,uuid,integer,date,date,integer,bigint,text,boolean) from public,anon;
grant execute on function public.prepare_rental_lease_draft(uuid,uuid,integer,integer,uuid,integer,date,date,integer,bigint,text,boolean) to authenticated;
create function private.invalidate_rental_lease_drafts() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status<>'approved' or new.version<>old.version then
  update public.rental_lease_drafts set state='voided',closed_at=now(),closed_reason='Application approval or participation changed' where application_id=new.id and state='prepared';
 end if;
 return new;
end $$;
revoke all on function private.invalidate_rental_lease_drafts() from public,anon,authenticated;
create trigger invalidate_rental_lease_drafts after update of status,version on public.rental_applications for each row execute function private.invalidate_rental_lease_drafts();
