create table public.rental_applications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id),
 organization_id uuid not null references public.organizations(id),
 listing_id uuid not null references public.listings(id),
 enquiry_id uuid references public.enquiries(id),
 request_id uuid not null,
 contact_name text not null check(length(trim(contact_name)) between 2 and 120),
 contact_email text not null,
 phone text not null default '' check(length(phone)<=40),
 household_size integer not null check(household_size between 1 and 20),
 desired_move_in date not null,
 message text not null check(length(trim(message)) between 10 and 2000),
 title_snapshot text not null,
 area_snapshot text not null,
 rent_jmd_snapshot numeric(14,2) not null check(rent_jmd_snapshot>0),
 consented_at timestamptz not null default now(),
 status text not null default 'submitted' check(status in('submitted','under_review','needs_info','approved','rejected','withdrawn','leased')),
 version integer not null default 1 check(version>0),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(user_id,request_id)
);
create index rental_applications_org_idx on public.rental_applications(organization_id,status,created_at desc);
create index rental_applications_user_idx on public.rental_applications(user_id,created_at desc);
create index rental_applications_listing_idx on public.rental_applications(listing_id);
create index rental_applications_enquiry_idx on public.rental_applications(enquiry_id);
create unique index rental_applications_one_active on public.rental_applications(user_id,listing_id) where status in('submitted','under_review','needs_info','approved');
alter table public.rental_applications enable row level security;
revoke all on public.rental_applications from public,anon,authenticated;
grant select on public.rental_applications to authenticated;
grant select,insert,update on public.rental_applications to service_role;
create policy "applicants read own applications" on public.rental_applications for select to authenticated using(user_id=(select auth.uid()));
create policy "verified staff read organization applications" on public.rental_applications for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));
create table public.rental_application_events (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.rental_applications(id) on delete cascade,
 actor_user_id uuid not null references auth.users(id),
 request_id uuid not null,
 event_name text not null,
 old_status text,
 new_status text not null,
 message text not null default '',
 version integer not null,
 created_at timestamptz not null default now(),
 unique(application_id,actor_user_id,request_id)
);
create index rental_application_events_app_idx on public.rental_application_events(application_id,created_at desc);
alter table public.rental_application_events enable row level security;
revoke all on public.rental_application_events from public,anon,authenticated;
grant select on public.rental_application_events to authenticated;
grant select,insert on public.rental_application_events to service_role;
create policy "read accessible application history" on public.rental_application_events for select to authenticated using(exists(select 1 from public.rental_applications where id=application_id));
alter table private.notification_outbox add column application_event_id uuid references public.rental_application_events(id);
alter table private.notification_outbox drop constraint notification_outbox_entity;
alter table private.notification_outbox add constraint notification_outbox_entity check(num_nonnulls(enquiry_id,viewing_event_id,seller_lead_id,application_event_id)=1);
create unique index notification_outbox_application_audience_idx on private.notification_outbox(application_event_id,audience) where application_event_id is not null;

create function private.record_application_event(p_application_id uuid,p_request_id uuid,p_event text,p_old_status text,p_message text) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); application public.rental_applications; event_id uuid; recipient_email text; details text;
begin
 select * into application from public.rental_applications where id=p_application_id;
 if caller is null or application.id is null or (caller<>application.user_id and application.organization_id is distinct from private.verified_enquiry_staff_organization()) then raise exception 'Application event access required' using errcode='42501';end if;
 insert into public.rental_application_events(application_id,actor_user_id,request_id,event_name,old_status,new_status,message,version) values(application.id,caller,p_request_id,p_event,p_old_status,application.status,p_message,application.version) returning id into event_id;
 update private.notification_outbox o set state='superseded',last_error='Superseded by a newer application event' where state='pending' and application_event_id in(select id from public.rental_application_events where application_id=application.id and id<>event_id);
 details:=E'Open House rental application\n\nReference: '||application.id::text||E'\nProperty: '||application.title_snapshot||E'\nStatus: '||application.status||E'\nEvent time (Jamaica): '||to_char(now() at time zone 'America/Jamaica','YYYY-MM-DD HH24:MI')||E'\n\n'||p_message||E'\n\nThe team reviews availability and verification before making an offer. Track the current application in your account.';
 select email into recipient_email from auth.users where id=application.user_id and email_confirmed_at is not null;
 if recipient_email is not null then insert into private.notification_outbox(application_event_id,audience,target_title,subject_snapshot,text_snapshot,recipient) values(event_id,'prospect',application.title_snapshot,'Application '||application.status||': '||application.title_snapshot,details,recipient_email);end if;
 insert into private.notification_outbox(application_event_id,audience,target_title,subject_snapshot,text_snapshot) values(event_id,'business',application.title_snapshot,'Application '||application.status||': '||application.title_snapshot,details||E'\nApplicant: '||application.contact_name||E'\nVerified contact at submission: '||application.contact_email||E'\nPhone: '||application.phone||E'\nHousehold size: '||application.household_size::text||E'\nDesired move-in: '||application.desired_move_in::text||E'\nAdvertised rent at submission: JMD '||application.rent_jmd_snapshot::text||E'\n\nInitial applicant message: '||application.message);
 return event_id;
end $$;
revoke all on function private.record_application_event(uuid,uuid,text,text,text) from public,anon,authenticated;

create function private.submit_rental_application(p_request_id uuid,p_listing_id uuid,p_enquiry_id uuid,p_contact_name text,p_phone text,p_household_size integer,p_desired_move_in date,p_message text,p_consent boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); email_address text; listing public.listings; existing public.rental_applications; created uuid; today date:=(now() at time zone 'America/Jamaica')::date;
begin
 if caller is null then raise exception 'Authentication required' using errcode='42501';end if;
 select email into email_address from auth.users where id=caller and email_confirmed_at is not null;
 if email_address is null then raise exception 'Verified email required' using errcode='42501';end if;
 if p_request_id is null or p_listing_id is null or p_consent is distinct from true or p_contact_name is null or length(trim(p_contact_name)) not between 2 and 120 or p_phone is null or length(p_phone)>40 or p_household_size is null or p_household_size not between 1 and 20 or p_desired_move_in is null or p_message is null or length(trim(p_message)) not between 10 and 2000 then raise exception 'Invalid rental application' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,111));
 select * into existing from public.rental_applications where user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.listing_id<>p_listing_id or existing.enquiry_id is distinct from p_enquiry_id or existing.contact_name<>trim(p_contact_name) or existing.phone<>trim(p_phone) or existing.household_size<>p_household_size or existing.desired_move_in<>p_desired_move_in or existing.message<>trim(p_message) then raise exception 'Request ID already used' using errcode='22023';end if;
  return existing.id;
 end if;
 if p_desired_move_in<today or p_desired_move_in>today+365 then raise exception 'Choose a move-in date within the next year' using errcode='22023';end if;
 if (select count(*) from public.rental_applications where user_id=caller and created_at>now()-interval '1 day')>=5 or (select count(*) from public.rental_applications where user_id=caller and status in('submitted','under_review','needs_info','approved'))>=3 then raise exception 'Application limit reached' using errcode='P0001';end if;
 select * into listing from public.listings where id=p_listing_id and status='published' and intent='rent' for share;
 if listing.id is null or listing.organization_id is null then raise exception 'Rental listing unavailable' using errcode='22023';end if;
 if exists(select 1 from public.rental_applications where user_id=caller and listing_id=listing.id and status in('submitted','under_review','needs_info','approved')) then raise exception 'An active application already exists for this listing' using errcode='23505';end if;
 if p_enquiry_id is not null and not exists(select 1 from public.enquiries where id=p_enquiry_id and user_id=caller and listing_id=listing.id and organization_id=listing.organization_id) then raise exception 'Enquiry reference unavailable' using errcode='22023';end if;
 insert into public.rental_applications(user_id,organization_id,listing_id,enquiry_id,request_id,contact_name,contact_email,phone,household_size,desired_move_in,message,title_snapshot,area_snapshot,rent_jmd_snapshot) values(caller,listing.organization_id,listing.id,p_enquiry_id,p_request_id,trim(p_contact_name),email_address,trim(p_phone),p_household_size,p_desired_move_in,trim(p_message),listing.title,listing.area,listing.price_jmd) returning id into created;
 perform private.record_application_event(created,p_request_id,'submitted',null,'Application submitted for team review.');
 return created;
end $$;
revoke all on function private.submit_rental_application(uuid,uuid,uuid,text,text,integer,date,text,boolean) from public,anon;
grant execute on function private.submit_rental_application(uuid,uuid,uuid,text,text,integer,date,text,boolean) to authenticated;
create function public.submit_rental_application(p_request_id uuid,p_listing_id uuid,p_enquiry_id uuid,p_contact_name text,p_phone text,p_household_size integer,p_desired_move_in date,p_message text,p_consent boolean) returns uuid language sql security invoker set search_path='' as $$select private.submit_rental_application(p_request_id,p_listing_id,p_enquiry_id,p_contact_name,p_phone,p_household_size,p_desired_move_in,p_message,p_consent);$$;
revoke all on function public.submit_rental_application(uuid,uuid,uuid,text,text,integer,date,text,boolean) from public,anon;
grant execute on function public.submit_rental_application(uuid,uuid,uuid,text,text,integer,date,text,boolean) to authenticated;

create function private.transition_rental_application(p_id uuid,p_request_id uuid,p_expected_version integer,p_action text,p_message text) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); application public.rental_applications; existing public.rental_application_events; org uuid; next_status text; today_event uuid;
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) then raise exception 'Verified identity required' using errcode='42501';end if;
 select * into application from public.rental_applications where id=p_id for update;
 org:=private.verified_enquiry_staff_organization();
 if application.id is null or (application.user_id<>caller and application.organization_id is distinct from org) then raise exception 'Application access required' using errcode='42501';end if;
 if p_request_id is null or p_expected_version is null or p_expected_version<1 or p_expected_version>=2147483647 or p_message is null or length(trim(p_message)) not between 5 and 2000 then raise exception 'Valid request/version and shared reason required' using errcode='22023';end if;
 if p_action in('start_review','request_info','reject') then
  if application.user_id=caller or application.organization_id is distinct from org then raise exception 'Independent organization reviewer required' using errcode='42501';end if;
 elsif p_action in('reply','withdraw') then
  if application.user_id<>caller then raise exception 'Applicant action required' using errcode='42501';end if;
 else raise exception 'Action unavailable until verification and approval workflow is configured' using errcode='22023';end if;
 select * into existing from public.rental_application_events where application_id=application.id and actor_user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.event_name<>p_action or existing.message<>trim(p_message) or existing.version<>p_expected_version+1 then raise exception 'Request ID already used' using errcode='22023';end if;
  return jsonb_build_object('status',application.status,'version',application.version);
 end if;
 if application.version<>p_expected_version then raise exception 'Application changed; refresh before retrying' using errcode='40001';end if;
 if p_action='start_review' and application.status='submitted' then next_status:='under_review';
 elsif p_action='request_info' and application.status='under_review' then next_status:='needs_info';
 elsif p_action='reject' and application.status in('under_review','needs_info') then next_status:='rejected';
 elsif p_action='reply' and application.status='needs_info' then next_status:='submitted';
 elsif p_action='withdraw' and application.status in('submitted','under_review','needs_info','approved') then next_status:='withdrawn';
 else raise exception 'Application stage does not allow this action' using errcode='22023';end if;
 update public.rental_applications set status=next_status,version=version+1,updated_at=now() where id=application.id;
 today_event:=private.record_application_event(application.id,p_request_id,p_action,application.status,trim(p_message));
 return jsonb_build_object('status',next_status,'version',application.version+1);
end $$;
revoke all on function private.transition_rental_application(uuid,uuid,integer,text,text) from public,anon;
grant execute on function private.transition_rental_application(uuid,uuid,integer,text,text) to authenticated;
create function public.transition_rental_application(p_id uuid,p_request_id uuid,p_expected_version integer,p_action text,p_message text) returns jsonb language sql security invoker set search_path='' as $$select private.transition_rental_application(p_id,p_request_id,p_expected_version,p_action,p_message);$$;
revoke all on function public.transition_rental_application(uuid,uuid,integer,text,text) from public,anon;
grant execute on function public.transition_rental_application(uuid,uuid,integer,text,text) to authenticated;
