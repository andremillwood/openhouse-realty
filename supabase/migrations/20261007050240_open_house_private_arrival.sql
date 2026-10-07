create table public.open_house_arrival (
 event_id uuid primary key references public.open_house_events(id),organization_id uuid not null references public.organizations(id),meeting_point text not null,details text not null,latitude double precision,longitude double precision,is_active boolean not null default true,version integer not null default 1 check(version>0),updated_at timestamptz not null default now(),check((latitude is null)=(longitude is null)),check(latitude is null or latitude between -90 and 90),check(longitude is null or longitude between -180 and 180)
);
create index open_house_arrival_org_idx on public.open_house_arrival(organization_id);
create table public.open_house_arrival_changes (
 id uuid primary key default gen_random_uuid(),event_id uuid not null references public.open_house_events(id),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,version integer not null,payload jsonb not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index open_house_arrival_changes_org_idx on public.open_house_arrival_changes(organization_id,created_at desc);
create index open_house_arrival_changes_event_idx on public.open_house_arrival_changes(event_id);
alter table public.open_house_arrival enable row level security;
alter table public.open_house_arrival_changes enable row level security;
revoke all on public.open_house_arrival,public.open_house_arrival_changes from public,anon,authenticated;
grant select on public.open_house_arrival,public.open_house_arrival_changes to authenticated;
grant select,insert,update on public.open_house_arrival to service_role;
grant select,insert on public.open_house_arrival_changes to service_role;
create function private.can_read_open_house_arrival(p_event uuid,p_org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) and exists(select 1 from public.open_house_rsvps r join public.open_house_events e on e.id=r.event_id join public.listings l on l.id=e.listing_id where r.user_id=auth.uid() and r.event_id=p_event and r.organization_id=p_org and r.status='going' and e.status='scheduled' and l.status='published' and l.organization_id=p_org and now()>=e.starts_at-interval '24 hours' and now()<e.ends_at);
$$;
revoke all on function private.can_read_open_house_arrival(uuid,uuid) from public,anon;
grant execute on function private.can_read_open_house_arrival(uuid,uuid) to authenticated;
create policy "verified staff read organization arrival instructions" on public.open_house_arrival for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));
create policy "reserved verified attendees read active imminent arrival instructions" on public.open_house_arrival for select to authenticated using(is_active and private.can_read_open_house_arrival(event_id,organization_id));
create policy "verified staff read organization arrival audit" on public.open_house_arrival_changes for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));
create function private.author_open_house_arrival(p_event_id uuid,p_request_id uuid,p_version integer,p_action text,p_meeting_point text,p_details text,p_latitude double precision,p_longitude double precision,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();event public.open_house_events;arrival public.open_house_arrival;existing public.open_house_arrival_changes;payload jsonb;
begin
 if caller is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_event_id is null or p_request_id is null or p_version is null or p_version not between 0 and 2147483646 or p_action is null or p_action not in('save','withdraw') or p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'Valid version/action/reason required' using errcode='22023';end if;
 payload:=jsonb_build_object('event',p_event_id,'version',p_version,'action',p_action,'meeting_point',trim(p_meeting_point),'details',trim(p_details),'latitude',p_latitude,'longitude',p_longitude,'reason',trim(p_reason),'approved',p_approved);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,71));
 select * into existing from public.open_house_arrival_changes where actor_user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.organization_id<>org or existing.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
  select * into arrival from public.open_house_arrival where event_id=existing.event_id;
  return jsonb_build_object('version',arrival.version,'is_active',arrival.is_active);
 end if;
 select e.* into event from public.open_house_events e join public.open_house_management m on m.event_id=e.id where e.id=p_event_id and m.organization_id=org for update of e;
 if event.id is null then raise exception 'Organization event required' using errcode='42501';end if;
 select * into arrival from public.open_house_arrival where event_id=event.id for update;
 if coalesce(arrival.version,0)<>p_version then raise exception 'Arrival instructions changed; refresh' using errcode='40001';end if;
 if p_action='save' then
  if event.status<>'scheduled' or event.ends_at<=now() or not exists(select 1 from public.listings where id=event.listing_id and organization_id=org and status='published') then raise exception 'Published upcoming event required' using errcode='42501';end if;
  if p_meeting_point is null or length(trim(p_meeting_point)) not between 3 and 250 or p_details is null or length(trim(p_details)) not between 10 and 2000 or p_approved is distinct from true or (p_latitude is null)<>(p_longitude is null) or (p_latitude is not null and (p_latitude not between -90 and 90 or p_longitude not between -180 and 180)) then raise exception 'Approved meeting instructions and paired valid coordinates required' using errcode='22023';end if;
  insert into public.open_house_arrival(event_id,organization_id,meeting_point,details,latitude,longitude) values(event.id,org,trim(p_meeting_point),trim(p_details),p_latitude,p_longitude) on conflict(event_id) do update set meeting_point=excluded.meeting_point,details=excluded.details,latitude=excluded.latitude,longitude=excluded.longitude,is_active=true,version=open_house_arrival.version+1,updated_at=now() returning * into arrival;
 else
  if arrival.event_id is null or p_meeting_point is not null or p_details is not null or p_latitude is not null or p_longitude is not null or p_approved is not null then raise exception 'Existing instructions and withdrawal fields required' using errcode='22023';end if;
  update public.open_house_arrival set is_active=false,version=version+1,updated_at=now() where event_id=event.id returning * into arrival;
 end if;
 insert into public.open_house_arrival_changes(event_id,organization_id,actor_user_id,request_id,version,payload) values(event.id,org,caller,p_request_id,arrival.version,payload);
 return jsonb_build_object('version',arrival.version,'is_active',arrival.is_active);
end $$;
revoke all on function private.author_open_house_arrival(uuid,uuid,integer,text,text,text,double precision,double precision,text,boolean) from public,anon;
grant execute on function private.author_open_house_arrival(uuid,uuid,integer,text,text,text,double precision,double precision,text,boolean) to authenticated;
create function public.author_open_house_arrival(p_event_id uuid,p_request_id uuid,p_version integer,p_action text,p_meeting_point text,p_details text,p_latitude double precision,p_longitude double precision,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.author_open_house_arrival(p_event_id,p_request_id,p_version,p_action,p_meeting_point,p_details,p_latitude,p_longitude,p_reason,p_approved);$$;
revoke all on function public.author_open_house_arrival(uuid,uuid,integer,text,text,text,double precision,double precision,text,boolean) from public,anon;
grant execute on function public.author_open_house_arrival(uuid,uuid,integer,text,text,text,double precision,double precision,text,boolean) to authenticated;
