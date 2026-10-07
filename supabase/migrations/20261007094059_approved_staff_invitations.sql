create function private.verified_staff_invitation_email() returns text language sql stable security definer set search_path='' as $$
 select lower(u.email) from auth.users u where u.id=auth.uid() and u.email_confirmed_at is not null;
$$;
revoke all on function private.verified_staff_invitation_email() from public,anon,authenticated,service_role;
grant execute on function private.verified_staff_invitation_email() to authenticated;
create table public.staff_invitations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),created_by uuid not null references auth.users(id),
 invite_email text not null check(invite_email=lower(trim(invite_email)) and length(invite_email) between 3 and 254 and invite_email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'),
 role text not null check(role in('admin','realtor','manager','finance')),state text not null default 'pending' check(state in('pending','accepted','declined','revoked','expired')),
 version integer not null default 1 check(version>0),expires_at timestamptz not null default statement_timestamp()+interval '7 days',created_at timestamptz not null default statement_timestamp(),
 accepted_by uuid references auth.users(id),responded_at timestamptz,check(state<>'accepted' or accepted_by is not null and responded_at is not null)
);
create unique index staff_invitations_pending_email_idx on public.staff_invitations(organization_id,invite_email) where state='pending';
create index staff_invitations_org_idx on public.staff_invitations(organization_id,state,created_at desc,id);
create index staff_invitations_recipient_idx on public.staff_invitations(invite_email,state,created_at desc,id);
alter table public.staff_invitations enable row level security;
revoke all on public.staff_invitations from public,anon,authenticated,service_role;
grant select(id,organization_id,invite_email,role,state,version,expires_at,created_at,accepted_by,responded_at) on public.staff_invitations to authenticated;
grant select on public.staff_invitations to service_role;
create policy "administrators read organization invitations" on public.staff_invitations for select to authenticated using(organization_id=(select private.verified_staff_admin_organization()));
create policy "verified recipients read their invitations" on public.staff_invitations for select to authenticated using(invite_email=(select private.verified_staff_invitation_email()));
create table public.staff_invitation_events(
 id uuid primary key default gen_random_uuid(),invitation_id uuid not null references public.staff_invitations(id),organization_id uuid not null references public.organizations(id),
 actor_user_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,action text not null check(action in('create','accept','decline','revoke','expire')),
 previous_state text,new_state text not null,version integer not null,reason text not null check(length(trim(reason)) between 5 and 500),created_at timestamptz not null default statement_timestamp(),unique(actor_user_id,request_id)
);
create index staff_invitation_events_scope_idx on public.staff_invitation_events(organization_id,invitation_id,created_at desc,id);
alter table public.staff_invitation_events enable row level security;
revoke all on public.staff_invitation_events from public,anon,authenticated,service_role;
grant select on public.staff_invitation_events to authenticated,service_role;
create policy "administrators read internal invitation approval events" on public.staff_invitation_events for select to authenticated using(organization_id=(select private.verified_staff_admin_organization()));
create trigger immutable_staff_invitation_events before update or delete on public.staff_invitation_events for each row execute function private.guard_finance_immutable();
alter table public.staff_membership_changes add column invitation_id uuid references public.staff_invitations(id);
create index staff_membership_changes_invitation_idx on public.staff_membership_changes(invitation_id) where invitation_id is not null;
create trigger immutable_staff_membership_changes before update or delete on public.staff_membership_changes for each row execute function private.guard_finance_immutable();
create function private.guard_staff_invitation() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if row(new.organization_id,new.created_by,new.invite_email,new.role,new.expires_at,new.created_at) is distinct from row(old.organization_id,old.created_by,old.invite_email,old.role,old.expires_at,old.created_at) then raise exception 'Invitation approval identity is immutable' using errcode='23505';end if;
 if old.state<>'pending' or new.state not in('accepted','declined','revoked','expired') or new.version<>old.version+1 then raise exception 'Invitation transition unavailable' using errcode='23505';end if;
 if new.state='accepted' and not exists(select 1 from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=new.accepted_by and s.organization_id=new.organization_id and s.role=new.role and lower(u.email)=new.invite_email and u.email_confirmed_at is not null) then raise exception 'Verified invited membership binding required' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.guard_staff_invitation() from public,anon,authenticated,service_role;
create trigger guard_staff_invitation before update on public.staff_invitations for each row execute function private.guard_staff_invitation();
create function private.manage_staff_invitation(p_request_id uuid,p_action text,p_invitation_id uuid,p_expected_version integer,p_email text,p_role text,p_reason text,p_approved boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();email text:=private.verified_staff_invitation_email();org uuid;inv public.staff_invitations;prior public.staff_invitation_events;old_inv public.staff_invitations;
 normalized text:=lower(trim(p_email));payload jsonb;created uuid;next_state text;next_version integer;revision uuid;confirmed timestamptz;
begin
 if caller is null or email is null then raise exception 'Verified account required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('create','accept','decline','revoke') or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Valid invitation action, revision, reason and explicit approval required' using errcode='22023';end if;
 if p_action='create' then
  org:=private.verified_staff_admin_organization();
  if org is null then raise exception 'Verified administrator required' using errcode='42501';end if;
  if p_invitation_id is not null or p_expected_version<>0 or p_email is null or length(normalized) not between 3 and 254 or normalized !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' or p_role is null or p_role not in('admin','realtor','manager','finance') then raise exception 'Approved invitation email and staff role required' using errcode='22023';end if;
 else
  if p_invitation_id is null or p_expected_version<1 or p_email is not null or p_role is not null then raise exception 'Current immutable invitation reference required' using errcode='22023';end if;
  select * into inv from public.staff_invitations where id=p_invitation_id;
  if inv.id is null then raise exception 'Invitation unavailable' using errcode='42501';end if;org:=inv.organization_id;
  if p_action='revoke' then
   if private.verified_staff_admin_organization() is distinct from org then raise exception 'Organization administrator required' using errcode='42501';end if;
  elsif inv.invite_email<>email then raise exception 'Verified invited email required' using errcode='42501';end if;
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_staff_invitation_email() is distinct from email or p_action in('create','revoke') and private.verified_staff_admin_organization() is distinct from org then raise exception 'Invitation authority changed' using errcode='42501';end if;
 payload:=jsonb_build_object('action',p_action,'invitation_id',p_invitation_id,'version',p_expected_version,'email',normalized,'role',p_role,'reason',trim(p_reason));
 select * into prior from public.staff_invitation_events where actor_user_id=caller and request_id=p_request_id;
 if prior.id is not null then
  if prior.organization_id<>org or prior.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
  return jsonb_build_object('id',prior.invitation_id,'state',prior.new_state,'version',prior.version);
 end if;
 if p_action='create' then
  if exists(select 1 from public.staff_accounts s join auth.users u on u.id=s.user_id where lower(u.email)=normalized) then raise exception 'Use membership management for an existing staff account' using errcode='42501';end if;
  for old_inv in select * from public.staff_invitations where organization_id=org and invite_email=normalized and state='pending' and expires_at<=statement_timestamp() for update loop
   update public.staff_invitations set state='expired',version=version+1 where id=old_inv.id;
   insert into public.staff_invitation_events(invitation_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(old_inv.id,org,caller,gen_random_uuid(),'{}','expire','pending','expired',old_inv.version+1,'Invitation expired before a new approval');
  end loop;
  if (select count(*) from public.staff_invitations where organization_id=org and state='pending' and expires_at>statement_timestamp())>=100 or (select count(*) from public.staff_invitation_events where actor_user_id=caller and action='create' and created_at>statement_timestamp()-interval '1 day')>=10 then raise exception 'Staff invitation limit reached' using errcode='23505';end if;
  insert into public.staff_invitations(organization_id,created_by,invite_email,role) values(org,caller,normalized,p_role) returning id into created;next_state:='pending';next_version:=1;
 else
  select * into inv from public.staff_invitations where id=p_invitation_id and organization_id=org for update;
  if inv.version<>p_expected_version then raise exception 'Invitation changed; refresh' using errcode='40001';end if;
  if inv.state<>'pending' then raise exception 'Invitation already closed; accepted roles use membership management' using errcode='23505';end if;
  if p_action in('accept','decline') and (inv.invite_email<>email or inv.expires_at<=statement_timestamp()) then raise exception 'Current verified email-bound invitation required' using errcode='42501';end if;
  if p_action='accept' then
   if not exists(select 1 from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=inv.created_by and s.organization_id=org and s.role='admin' and u.email_confirmed_at is not null) then raise exception 'Inviting administrator approval is no longer current' using errcode='42501';end if;
   -- Serialize competing invitations/membership changes for this verified Auth identity.
   select email_confirmed_at into confirmed from auth.users where id=caller and lower(auth.users.email)=inv.invite_email for update;
   if not found or confirmed is null then raise exception 'Verified invited identity required' using errcode='42501';end if;
   if exists(select 1 from public.staff_accounts where user_id=caller) then raise exception 'Existing staff access must be managed by its administrator' using errcode='23505';end if;
   revision:=gen_random_uuid();insert into public.staff_accounts(user_id,organization_id,role,membership_revision) values(caller,org,inv.role,revision);next_state:='accepted';
  elsif p_action='decline' then next_state:='declined';else next_state:='revoked';end if;
  created:=inv.id;next_version:=inv.version+1;
  update public.staff_invitations set state=next_state,version=next_version,accepted_by=case when p_action='accept' then caller else null end,responded_at=case when p_action in('accept','decline') then statement_timestamp() else null end where id=inv.id;
  if p_action='accept' then insert into public.staff_membership_changes(organization_id,actor_user_id,target_user_id,target_email,request_id,new_role,new_revision,reason,invitation_id) values(org,caller,caller,email,p_request_id,inv.role,revision,'Accepted administrator-approved staff invitation',inv.id);end if;
 end if;
 insert into public.staff_invitation_events(invitation_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(created,org,caller,p_request_id,payload,p_action,inv.state,next_state,next_version,trim(p_reason));
 return jsonb_build_object('id',created,'state',next_state,'version',next_version);
end $$;
revoke all on function private.manage_staff_invitation(uuid,text,uuid,integer,text,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.manage_staff_invitation(uuid,text,uuid,integer,text,text,text,boolean) to authenticated;
create function public.manage_staff_invitation(p_request_id uuid,p_action text,p_invitation_id uuid,p_expected_version integer,p_email text,p_role text,p_reason text,p_approved boolean) returns jsonb
language sql security invoker set search_path='' as $$select private.manage_staff_invitation(p_request_id,p_action,p_invitation_id,p_expected_version,p_email,p_role,p_reason,p_approved);$$;
revoke all on function public.manage_staff_invitation(uuid,text,uuid,integer,text,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.manage_staff_invitation(uuid,text,uuid,integer,text,text,text,boolean) to authenticated;
