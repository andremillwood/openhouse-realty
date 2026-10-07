-- Internal collaboration stays separate from prospect-readable enquiry records.
create table public.enquiry_assignments (
 enquiry_id uuid primary key references public.enquiries(id) on delete cascade,
 organization_id uuid not null references public.organizations(id),
 assignee_user_id uuid references auth.users(id),
 version integer not null default 1 check (version > 0),
 updated_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now()
);
create index enquiry_assignments_org_idx on public.enquiry_assignments(organization_id,assignee_user_id);
create table public.enquiry_staff_notes (
 id uuid primary key default gen_random_uuid(),
 enquiry_id uuid not null references public.enquiries(id) on delete cascade,
 organization_id uuid not null references public.organizations(id),
 author_user_id uuid not null references auth.users(id),
 request_id uuid not null,
 body text not null check (length(trim(body)) between 2 and 2000),
 created_at timestamptz not null default now(),
 unique(author_user_id,request_id)
);
create index enquiry_staff_notes_org_idx on public.enquiry_staff_notes(organization_id,enquiry_id,created_at desc);
create index enquiry_staff_notes_author_idx on public.enquiry_staff_notes(author_user_id,created_at desc);
create table public.enquiry_assignment_events (
 id uuid primary key default gen_random_uuid(),
 enquiry_id uuid not null references public.enquiries(id) on delete cascade,
 organization_id uuid not null references public.organizations(id),
 actor_user_id uuid not null references auth.users(id),
 previous_assignee_user_id uuid references auth.users(id),
 assignee_user_id uuid references auth.users(id),
 version integer not null,
 created_at timestamptz not null default now()
);
create index enquiry_assignment_events_org_idx on public.enquiry_assignment_events(organization_id,enquiry_id,created_at desc);
alter table public.enquiry_assignments enable row level security;
alter table public.enquiry_staff_notes enable row level security;
alter table public.enquiry_assignment_events enable row level security;
revoke all on public.enquiry_assignments,public.enquiry_staff_notes,public.enquiry_assignment_events from public,anon,authenticated;
grant select on public.enquiry_assignments,public.enquiry_staff_notes,public.enquiry_assignment_events to authenticated;
grant select,insert,update on public.enquiry_assignments to service_role;
grant select,insert on public.enquiry_staff_notes,public.enquiry_assignment_events to service_role;
create policy "staff read organization assignments" on public.enquiry_assignments for select to authenticated using (organization_id in (select organization_id from public.staff_accounts where user_id=(select auth.uid()) and role in ('admin','realtor','manager')));
create policy "staff read organization notes" on public.enquiry_staff_notes for select to authenticated using (organization_id in (select organization_id from public.staff_accounts where user_id=(select auth.uid()) and role in ('admin','realtor','manager')));
create policy "staff read organization assignment history" on public.enquiry_assignment_events for select to authenticated using (organization_id in (select organization_id from public.staff_accounts where user_id=(select auth.uid()) and role in ('admin','realtor','manager')));

create function private.enquiry_staff_directory()
returns table(user_id uuid,display_name text,role text)
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); org uuid;
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) then raise exception 'Verified staff required' using errcode='42501'; end if;
 select organization_id into org from public.staff_accounts where staff_accounts.user_id=caller and staff_accounts.role in ('admin','realtor','manager');
 if org is null then raise exception 'Staff access required' using errcode='42501'; end if;
 return query select s.user_id,left(nullif(trim(p.display_name),''),120),s.role from public.staff_accounts s left join public.profiles p on p.id=s.user_id join auth.users u on u.id=s.user_id and u.email_confirmed_at is not null where s.organization_id=org and s.role in ('admin','realtor','manager') order by p.display_name nulls last,s.user_id;
end $$;
revoke all on function private.enquiry_staff_directory() from public,anon;
grant execute on function private.enquiry_staff_directory() to authenticated;
create function public.enquiry_staff_directory() returns table(user_id uuid,display_name text,role text) language sql security invoker set search_path='' as $$ select * from private.enquiry_staff_directory(); $$;
revoke all on function public.enquiry_staff_directory() from public,anon;
grant execute on function public.enquiry_staff_directory() to authenticated;

create function private.collaborate_enquiry(p_enquiry_id uuid,p_action text,p_assignee_user_id uuid,p_expected_version integer,p_request_id uuid,p_body text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); org uuid; target_org uuid; current_assignment public.enquiry_assignments; existing_note public.enquiry_staff_notes; new_id uuid; next_version integer;
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) then raise exception 'Verified staff required' using errcode='42501'; end if;
 select organization_id into org from public.staff_accounts where user_id=caller and role in ('admin','realtor','manager');
 if org is null then raise exception 'Staff access required' using errcode='42501'; end if;
 -- Serialize retries for notes even if a request ID is reused across enquiries.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,77));
 select organization_id into target_org from public.enquiries where id=p_enquiry_id for update;
 if target_org is null or target_org<>org then raise exception 'Enquiry unavailable' using errcode='42501'; end if;
 if p_action='assign' then
  if p_expected_version is null or p_expected_version<0 then raise exception 'Assignment version required' using errcode='22023'; end if;
  if p_assignee_user_id is not null and not exists(select 1 from public.staff_accounts s join auth.users u on u.id=s.user_id and u.email_confirmed_at is not null where s.user_id=p_assignee_user_id and s.organization_id=org and s.role in ('admin','realtor','manager')) then raise exception 'Assignee unavailable' using errcode='22023'; end if;
  select * into current_assignment from public.enquiry_assignments where enquiry_id=p_enquiry_id;
  -- Exact retry of the preceding successful assignment produces no extra event.
  if current_assignment.version=p_expected_version+1 and current_assignment.updated_by=caller and current_assignment.assignee_user_id is not distinct from p_assignee_user_id then return jsonb_build_object('version',current_assignment.version,'assignee_user_id',current_assignment.assignee_user_id); end if;
  if coalesce(current_assignment.version,0)<>p_expected_version then raise exception 'Assignment changed; refresh before retrying' using errcode='40001'; end if;
  if current_assignment.enquiry_id is not null and current_assignment.assignee_user_id is not distinct from p_assignee_user_id then return jsonb_build_object('version',current_assignment.version,'assignee_user_id',current_assignment.assignee_user_id); end if;
  next_version:=p_expected_version+1;
  insert into public.enquiry_assignments(enquiry_id,organization_id,assignee_user_id,version,updated_by) values(p_enquiry_id,org,p_assignee_user_id,next_version,caller) on conflict(enquiry_id) do update set assignee_user_id=excluded.assignee_user_id,version=excluded.version,updated_by=excluded.updated_by,updated_at=now();
  insert into public.enquiry_assignment_events(enquiry_id,organization_id,actor_user_id,previous_assignee_user_id,assignee_user_id,version) values(p_enquiry_id,org,caller,current_assignment.assignee_user_id,p_assignee_user_id,next_version);
  return jsonb_build_object('version',next_version,'assignee_user_id',p_assignee_user_id);
 elsif p_action='note' then
  if p_request_id is null or p_body is null or length(trim(p_body)) not between 2 and 2000 then raise exception 'Invalid staff note' using errcode='22023'; end if;
  select * into existing_note from public.enquiry_staff_notes where author_user_id=caller and request_id=p_request_id;
  if existing_note.id is not null then
   if existing_note.enquiry_id<>p_enquiry_id or existing_note.body<>trim(p_body) then raise exception 'Request ID already used' using errcode='22023'; end if;
   return jsonb_build_object('note_id',existing_note.id);
  end if;
  if (select count(*) from public.enquiry_staff_notes where author_user_id=caller and created_at>now()-interval '1 day')>=200 then raise exception 'Daily note limit reached' using errcode='P0001'; end if;
  insert into public.enquiry_staff_notes(enquiry_id,organization_id,author_user_id,request_id,body) values(p_enquiry_id,org,caller,p_request_id,trim(p_body)) returning id into new_id;
  return jsonb_build_object('note_id',new_id);
 end if;
 raise exception 'Invalid collaboration action' using errcode='22023';
end $$;
revoke all on function private.collaborate_enquiry(uuid,text,uuid,integer,uuid,text) from public,anon;
grant execute on function private.collaborate_enquiry(uuid,text,uuid,integer,uuid,text) to authenticated;
create function public.collaborate_enquiry(p_enquiry_id uuid,p_action text,p_assignee_user_id uuid,p_expected_version integer,p_request_id uuid,p_body text) returns jsonb language sql security invoker set search_path='' as $$ select private.collaborate_enquiry(p_enquiry_id,p_action,p_assignee_user_id,p_expected_version,p_request_id,p_body); $$;
revoke all on function public.collaborate_enquiry(uuid,text,uuid,integer,uuid,text) from public,anon;
grant execute on function public.collaborate_enquiry(uuid,text,uuid,integer,uuid,text) to authenticated;
