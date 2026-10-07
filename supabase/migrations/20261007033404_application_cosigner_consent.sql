create table public.application_cosigners (
 id uuid primary key default gen_random_uuid(), application_id uuid not null references public.rental_applications(id),
 organization_id uuid not null references public.organizations(id), applicant_user_id uuid not null references auth.users(id),
 invite_email text not null, recipient_user_id uuid references auth.users(id), request_id uuid not null,
 applicant_name_snapshot text not null,title_snapshot text not null,area_snapshot text not null,rent_jmd_snapshot numeric(14,2) not null,
 state text not null default 'pending' check(state in('pending','accepted','declined','revoked','withdrawn')),
 consent_version integer,consented_at timestamptz, expires_at timestamptz not null default now()+interval '7 days',
 version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(applicant_user_id,request_id)
);
create unique index application_cosigners_active_email_idx on public.application_cosigners(application_id,invite_email) where state in('pending','accepted');
create index application_cosigners_app_idx on public.application_cosigners(application_id);
create index application_cosigners_applicant_idx on public.application_cosigners(applicant_user_id,created_at desc);
create index application_cosigners_email_idx on public.application_cosigners(invite_email);
create index application_cosigners_recipient_idx on public.application_cosigners(recipient_user_id);
create index application_cosigners_org_idx on public.application_cosigners(organization_id);
create table public.application_cosigner_events (
 id uuid primary key default gen_random_uuid(),cosigner_id uuid not null references public.application_cosigners(id),
 actor_user_id uuid not null references auth.users(id),request_id uuid not null,event_name text not null,
 new_state text not null,version integer not null,created_at timestamptz not null default now(),unique(cosigner_id,actor_user_id,request_id)
);
create index application_cosigner_events_cosigner_idx on public.application_cosigner_events(cosigner_id,created_at desc);
alter table public.application_cosigners enable row level security;
alter table public.application_cosigner_events enable row level security;
revoke all on public.application_cosigners,public.application_cosigner_events from public,anon,authenticated;
grant select on public.application_cosigners,public.application_cosigner_events to authenticated;
grant select,insert,update on public.application_cosigners to service_role;
grant select,insert on public.application_cosigner_events to service_role;
create function private.verified_cosigner_email() returns text language sql stable security definer set search_path='' as $$select lower(email) from auth.users where id=auth.uid() and email_confirmed_at is not null;$$;
revoke all on function private.verified_cosigner_email() from public,anon;
grant execute on function private.verified_cosigner_email() to authenticated;
create policy "applicant reads co-signer invitations" on public.application_cosigners for select to authenticated using(applicant_user_id=(select auth.uid()));
create policy "verified recipient reads limited co-signer invitation" on public.application_cosigners for select to authenticated using((recipient_user_id=(select auth.uid()) and (select private.verified_cosigner_email()) is not null) or (recipient_user_id is null and state='pending' and invite_email=(select private.verified_cosigner_email()) and expires_at>now()));
create policy "organization staff reads co-signer invitations" on public.application_cosigners for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));
create policy "participants read co-signer audit" on public.application_cosigner_events for select to authenticated using(exists(select 1 from public.application_cosigners c where c.id=cosigner_id and (c.applicant_user_id=(select auth.uid()) or (c.recipient_user_id=(select auth.uid()) and (select private.verified_cosigner_email()) is not null) or (c.recipient_user_id is null and c.state='pending' and c.invite_email=(select private.verified_cosigner_email()) and c.expires_at>now()) or c.organization_id=(select private.verified_enquiry_staff_organization()))));

create function private.invite_application_cosigner(p_application_id uuid,p_request_id uuid,p_email text,p_permission boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();email_address text:=private.verified_cosigner_email();application public.rental_applications;existing public.application_cosigners;created uuid;normalized text:=lower(trim(p_email));
begin
 if email_address is null then raise exception 'Verified applicant required' using errcode='42501';end if;
 if p_request_id is null or p_permission is distinct from true or normalized is null or length(normalized)>254 or normalized !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or normalized=email_address then raise exception 'Valid other recipient email and sharing permission required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,114));
 select * into application from public.rental_applications where id=p_application_id for update;
 if application.id is null or application.user_id<>caller then raise exception 'Applicant access required' using errcode='42501';end if;
 select * into existing from public.application_cosigners where applicant_user_id=caller and request_id=p_request_id;
 if existing.id is not null then if existing.application_id<>p_application_id or existing.invite_email<>normalized then raise exception 'Request ID already used' using errcode='22023';end if;return existing.id;end if;
 if application.status not in('submitted','under_review','needs_info') then raise exception 'Application invitation stage closed' using errcode='22023';end if;
 with expired as (update public.application_cosigners set state='revoked',version=version+1,updated_at=now() where application_id=application.id and state='pending' and expires_at<=now() returning id,version) insert into public.application_cosigner_events(cosigner_id,actor_user_id,request_id,event_name,new_state,version) select id,caller,gen_random_uuid(),'expired','revoked',version from expired;
 if (select count(*) from public.application_cosigners where application_id=application.id and state in('pending','accepted'))>=2 or (select count(*) from public.application_cosigners where applicant_user_id=caller and created_at>now()-interval '1 day')>=5 then raise exception 'Co-signer invitation limit reached' using errcode='P0001';end if;
 insert into public.application_cosigners(application_id,organization_id,applicant_user_id,invite_email,request_id,applicant_name_snapshot,title_snapshot,area_snapshot,rent_jmd_snapshot) values(application.id,application.organization_id,caller,normalized,p_request_id,application.contact_name,application.title_snapshot,application.area_snapshot,application.rent_jmd_snapshot) returning id into created;
 insert into public.application_cosigner_events(cosigner_id,actor_user_id,request_id,event_name,new_state,version) values(created,caller,p_request_id,'invited','pending',1);
 update public.rental_applications set version=version+1,updated_at=now() where id=application.id;
 return created;
end $$;
revoke all on function private.invite_application_cosigner(uuid,uuid,text,boolean) from public,anon;
grant execute on function private.invite_application_cosigner(uuid,uuid,text,boolean) to authenticated;
create function public.invite_application_cosigner(p_application_id uuid,p_request_id uuid,p_email text,p_permission boolean) returns uuid language sql security invoker set search_path='' as $$select private.invite_application_cosigner(p_application_id,p_request_id,p_email,p_permission);$$;
revoke all on function public.invite_application_cosigner(uuid,uuid,text,boolean) from public,anon;
grant execute on function public.invite_application_cosigner(uuid,uuid,text,boolean) to authenticated;

create function private.respond_application_cosigner(p_id uuid,p_request_id uuid,p_expected_version integer,p_action text,p_consent boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();email_address text:=private.verified_cosigner_email();invitation public.application_cosigners;application public.rental_applications;existing public.application_cosigner_events;next_state text;
begin
 if email_address is null then raise exception 'Verified participant required' using errcode='42501';end if;
 if p_request_id is null or p_expected_version is null or p_expected_version<1 or p_expected_version>=2147483647 then raise exception 'Valid request and version required' using errcode='22023';end if;
 select * into invitation from public.application_cosigners where id=p_id;
 select * into application from public.rental_applications where id=invitation.application_id for update;
 select * into invitation from public.application_cosigners where id=p_id for update;
 if invitation.id is null then raise exception 'Invitation unavailable' using errcode='42501';end if;
 if p_action='revoke' then if caller<>invitation.applicant_user_id then raise exception 'Applicant action required' using errcode='42501';end if;
 elsif p_action in('accept','decline','withdraw') then
  if caller=invitation.applicant_user_id or (invitation.recipient_user_id is not null and invitation.recipient_user_id<>caller) or (invitation.recipient_user_id is null and invitation.invite_email<>email_address) then raise exception 'Invited verified recipient required' using errcode='42501';end if;
  if p_action='accept' and p_consent is distinct from true then raise exception 'Explicit review consent required' using errcode='22023';end if;
 else raise exception 'Invalid co-signer action' using errcode='22023';end if;
 select * into existing from public.application_cosigner_events where cosigner_id=invitation.id and actor_user_id=caller and request_id=p_request_id;
 if existing.id is not null then if existing.event_name<>p_action or existing.version<>p_expected_version+1 then raise exception 'Request ID already used' using errcode='22023';end if;return jsonb_build_object('state',invitation.state,'version',invitation.version);end if;
 if invitation.version<>p_expected_version then raise exception 'Invitation changed; refresh first' using errcode='40001';end if;
 if application.status not in('submitted','under_review','needs_info','approved') then raise exception 'Application stage closed' using errcode='22023';end if;
 if p_action='revoke' and invitation.state in('pending','accepted') then next_state:='revoked';
 elsif p_action='withdraw' and invitation.state='accepted' then next_state:='withdrawn';
 elsif p_action in('accept','decline') and invitation.state='pending' and invitation.expires_at>now() then next_state:=case when p_action='accept' then 'accepted' else 'declined' end;
 else raise exception 'Invitation does not allow this action' using errcode='22023';end if;
 update public.application_cosigners set state=next_state,recipient_user_id=case when p_action in('accept','decline') then caller else recipient_user_id end,consent_version=case when p_action='accept' then 1 else consent_version end,consented_at=case when p_action='accept' then now() else consented_at end,version=version+1,updated_at=now() where id=invitation.id;
 insert into public.application_cosigner_events(cosigner_id,actor_user_id,request_id,event_name,new_state,version) values(invitation.id,caller,p_request_id,p_action,next_state,invitation.version+1);
 update public.rental_applications set status=case when status='approved' then 'under_review' else status end,version=version+1,updated_at=now() where id=application.id;
 return jsonb_build_object('state',next_state,'version',invitation.version+1);
end $$;
revoke all on function private.respond_application_cosigner(uuid,uuid,integer,text,boolean) from public,anon;
grant execute on function private.respond_application_cosigner(uuid,uuid,integer,text,boolean) to authenticated;
create function public.respond_application_cosigner(p_id uuid,p_request_id uuid,p_expected_version integer,p_action text,p_consent boolean) returns jsonb language sql security invoker set search_path='' as $$select private.respond_application_cosigner(p_id,p_request_id,p_expected_version,p_action,p_consent);$$;
revoke all on function public.respond_application_cosigner(uuid,uuid,integer,text,boolean) from public,anon;
grant execute on function public.respond_application_cosigner(uuid,uuid,integer,text,boolean) to authenticated;
create function private.cosigner_invitation_active(p_id uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare invitation public.application_cosigners;caller uuid:=auth.uid();email_address text:=private.verified_cosigner_email();
begin
 select * into invitation from public.application_cosigners where id=p_id;
 if email_address is null or invitation.id is null or not coalesce((caller=invitation.applicant_user_id or caller=invitation.recipient_user_id or (invitation.recipient_user_id is null and invitation.state='pending' and invitation.invite_email=email_address and invitation.expires_at>now()) or invitation.organization_id=private.verified_enquiry_staff_organization()),false) then return false;end if;
 return invitation.state in('pending','accepted') and (invitation.state='accepted' or invitation.expires_at>now()) and exists(select 1 from public.rental_applications where id=invitation.application_id and status in('submitted','under_review','needs_info','approved'));
end $$;
revoke all on function private.cosigner_invitation_active(uuid) from public,anon;
grant execute on function private.cosigner_invitation_active(uuid) to authenticated;
create function public.cosigner_invitation_active(p_id uuid) returns boolean language sql security invoker set search_path='' as $$select private.cosigner_invitation_active(p_id);$$;
revoke all on function public.cosigner_invitation_active(uuid) from public,anon;
grant execute on function public.cosigner_invitation_active(uuid) to authenticated;
