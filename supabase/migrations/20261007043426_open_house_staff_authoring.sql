create table public.open_house_management (
 event_id uuid primary key references public.open_house_events(id),organization_id uuid not null references public.organizations(id),host_user_id uuid references auth.users(id),version integer not null default 1 check(version>0)
);
insert into public.open_house_management(event_id,organization_id) select e.id,l.organization_id from public.open_house_events e join public.listings l on l.id=e.listing_id;
create index open_house_management_org_idx on public.open_house_management(organization_id);
create index open_house_management_host_idx on public.open_house_management(host_user_id);
create table public.open_house_author_events (
 id uuid primary key default gen_random_uuid(),event_id uuid not null references public.open_house_events(id),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,version integer not null,action text not null,payload jsonb not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index open_house_author_events_org_idx on public.open_house_author_events(organization_id,created_at desc);
create index open_house_author_events_event_idx on public.open_house_author_events(event_id,created_at desc);
alter table public.open_house_management enable row level security;
alter table public.open_house_author_events enable row level security;
revoke all on public.open_house_management,public.open_house_author_events from public,anon,authenticated;
grant select on public.open_house_management,public.open_house_author_events to authenticated;
grant select,insert,update on public.open_house_management to service_role;
grant select,insert on public.open_house_author_events to service_role;
create policy "verified staff read organization open house management" on public.open_house_management for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));
create policy "verified staff read organization open house author audit" on public.open_house_author_events for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));
create policy "verified staff read organization open houses" on public.open_house_events for select to authenticated using(exists(select 1 from public.open_house_management m where m.event_id=open_house_events.id and m.organization_id=(select private.verified_enquiry_staff_organization())));
drop policy "scheduled open houses for published listings are public" on public.open_house_events;
create policy "scheduled open houses for published listings are public" on public.open_house_events for select to anon,authenticated using(status='scheduled' and ends_at>now() and exists(select 1 from public.listings where id=listing_id and status='published'));
revoke insert,update,delete on public.open_house_events from anon,authenticated;
grant select,insert,update on public.open_house_events to service_role;
create index open_house_events_schedule_idx on public.open_house_events(status,starts_at,id);
create function private.author_open_house_event(p_action text,p_request_id uuid,p_event_id uuid,p_expected_version integer,p_listing_id uuid,p_title text,p_starts_at timestamptz,p_ends_at timestamptz,p_capacity integer,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();event public.open_house_events;management public.open_house_management;existing public.open_house_author_events;payload jsonb;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('create','cancel','complete') or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 then raise exception 'Valid action/request/version required' using errcode='22023';end if;
 payload:=jsonb_build_object('action',p_action,'event_id',p_event_id,'version',p_expected_version,'listing_id',p_listing_id,'title',trim(p_title),'starts_at',p_starts_at,'ends_at',p_ends_at,'capacity',p_capacity,'reason',trim(p_reason),'approved',p_approved);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,71));
 select * into existing from public.open_house_author_events where actor_user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.organization_id<>org or existing.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
  select * into management from public.open_house_management where event_id=existing.event_id;
  select * into event from public.open_house_events where id=existing.event_id;
  return jsonb_build_object('event_id',event.id,'version',management.version,'status',event.status);
 end if;
 if p_action='create' then
  if p_reason is not null or p_event_id is not null or p_expected_version<>0 or p_title is null or length(trim(p_title)) not between 3 and 160 or p_capacity is null or p_capacity not between 1 and 250 or p_starts_at is null or p_ends_at is null or p_starts_at<now()+interval '30 minutes' or p_starts_at>now()+interval '120 days' or p_ends_at-p_starts_at not between interval '15 minutes' and interval '8 hours' or p_approved is distinct from true then raise exception 'Approved title, capacity and future event window required' using errcode='22023';end if;
  if not exists(select 1 from public.listings where id=p_listing_id and organization_id=org and status='published') then raise exception 'Published organization listing required' using errcode='42501';end if;
  if exists(select 1 from public.open_house_events e join public.open_house_management m on m.event_id=e.id where e.status='scheduled' and tstzrange(e.starts_at,e.ends_at,'[)') && tstzrange(p_starts_at,p_ends_at,'[)') and (e.listing_id=p_listing_id or m.host_user_id=caller)) or exists(select 1 from public.viewing_slots s left join private.viewing_slot_hosts h on h.slot_id=s.id where s.state<>'closed' and tstzrange(s.starts_at,s.ends_at,'[)') && tstzrange(p_starts_at,p_ends_at,'[)') and (s.listing_id=p_listing_id or h.host_user_id=caller)) then raise exception 'Property or host already scheduled' using errcode='23505';end if;
  if (select count(*) from public.open_house_author_events where actor_user_id=caller and action='create' and created_at>now()-interval '1 day')>=50 then raise exception 'Daily authoring limit reached' using errcode='22023';end if;
  insert into public.open_house_events(listing_id,title,starts_at,ends_at,capacity) values(p_listing_id,trim(p_title),p_starts_at,p_ends_at,p_capacity) returning id into created;
  insert into public.open_house_management(event_id,organization_id,host_user_id) values(created,org,caller);
 else
  if p_listing_id is not null or p_title is not null or p_starts_at is not null or p_ends_at is not null or p_capacity is not null or p_approved is not null then raise exception 'Resolution fields only' using errcode='22023';end if;
  select * into management from public.open_house_management where event_id=p_event_id and organization_id=org for update;
  if management.event_id is null then raise exception 'Organization event required' using errcode='42501';end if;
  select * into event from public.open_house_events where id=p_event_id for update;
  if management.version<>p_expected_version then raise exception 'Event changed; refresh' using errcode='40001';end if;
  if event.status<>'scheduled' or (p_action='complete' and event.ends_at>now()) or p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'Valid resolution window and reason required' using errcode='22023';end if;
  update public.open_house_events set status=case when p_action='cancel' then 'cancelled' else 'completed' end where id=event.id;
  update public.open_house_management set version=version+1 where event_id=event.id;
  created:=event.id;
 end if;
 select * into management from public.open_house_management where event_id=created;
 select * into event from public.open_house_events where id=created;
 insert into public.open_house_author_events(event_id,organization_id,actor_user_id,request_id,version,action,payload) values(created,org,caller,p_request_id,management.version,p_action,payload);
 return jsonb_build_object('event_id',created,'version',management.version,'status',event.status);
end $$;
revoke all on function private.author_open_house_event(text,uuid,uuid,integer,uuid,text,timestamptz,timestamptz,integer,text,boolean) from public,anon;
grant execute on function private.author_open_house_event(text,uuid,uuid,integer,uuid,text,timestamptz,timestamptz,integer,text,boolean) to authenticated;
create function public.author_open_house_event(p_action text,p_request_id uuid,p_event_id uuid,p_expected_version integer,p_listing_id uuid,p_title text,p_starts_at timestamptz,p_ends_at timestamptz,p_capacity integer,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.author_open_house_event(p_action,p_request_id,p_event_id,p_expected_version,p_listing_id,p_title,p_starts_at,p_ends_at,p_capacity,p_reason,p_approved);$$;
revoke all on function public.author_open_house_event(text,uuid,uuid,integer,uuid,text,timestamptz,timestamptz,integer,text,boolean) from public,anon;
grant execute on function public.author_open_house_event(text,uuid,uuid,integer,uuid,text,timestamptz,timestamptz,integer,text,boolean) to authenticated;
create function private.guard_viewing_open_house_conflict() returns trigger language plpgsql security definer set search_path='' as $$
declare slot public.viewing_slots;host uuid;
begin
 if tg_table_name='viewing_slots' then slot:=new;
 else select * into slot from public.viewing_slots where id=new.slot_id;host:=new.host_user_id;end if;
 if slot.state<>'closed' and exists(select 1 from public.open_house_events e join public.open_house_management m on m.event_id=e.id where e.status='scheduled' and tstzrange(e.starts_at,e.ends_at,'[)') && tstzrange(slot.starts_at,slot.ends_at,'[)') and (e.listing_id=slot.listing_id or m.host_user_id=host)) then raise exception 'Open house property or host conflict' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.guard_viewing_open_house_conflict() from public,anon,authenticated;
create trigger guard_viewing_open_house_property before insert on public.viewing_slots for each row execute function private.guard_viewing_open_house_conflict();
create trigger guard_viewing_open_house_host before insert on private.viewing_slot_hosts for each row execute function private.guard_viewing_open_house_conflict();
