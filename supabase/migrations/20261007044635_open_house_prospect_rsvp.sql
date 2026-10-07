create table public.open_house_rsvps (
 id uuid primary key default gen_random_uuid(),event_id uuid not null references public.open_house_events(id),organization_id uuid not null references public.organizations(id),user_id uuid not null references auth.users(id),party_size integer not null check(party_size between 1 and 6),status text not null check(status in('going','cancelled')),version integer not null default 1 check(version>0),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(event_id,user_id)
);
create index open_house_rsvps_org_idx on public.open_house_rsvps(organization_id,event_id);
create index open_house_rsvps_user_idx on public.open_house_rsvps(user_id,created_at desc);
create table public.open_house_rsvp_changes (
 id uuid primary key default gen_random_uuid(),rsvp_id uuid not null references public.open_house_rsvps(id),user_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,created_at timestamptz not null default now(),unique(user_id,request_id)
);
create index open_house_rsvp_changes_rsvp_idx on public.open_house_rsvp_changes(rsvp_id);
alter table public.open_house_rsvps enable row level security;
alter table public.open_house_rsvp_changes enable row level security;
revoke all on public.open_house_rsvps,public.open_house_rsvp_changes from public,anon,authenticated;
grant select on public.open_house_rsvps,public.open_house_rsvp_changes to authenticated;
grant select,insert,update on public.open_house_rsvps to service_role;
grant select,insert on public.open_house_rsvp_changes to service_role;
create policy "prospects read own open house reservations" on public.open_house_rsvps for select to authenticated using(user_id=(select auth.uid()));
create policy "verified staff read organization open house reservations" on public.open_house_rsvps for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));
create policy "prospects read own reservation changes" on public.open_house_rsvp_changes for select to authenticated using(user_id=(select auth.uid()));
create function private.reserve_open_house(p_event_id uuid,p_request_id uuid,p_expected_version integer,p_party_size integer,p_action text,p_consent boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();event public.open_house_events;rsvp public.open_house_rsvps;existing public.open_house_rsvp_changes;org uuid;payload jsonb;
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) then raise exception 'Verified account required' using errcode='42501';end if;
 if p_event_id is null or p_request_id is null or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_action is null or p_action not in('reserve','cancel') then raise exception 'Valid reservation request required' using errcode='22023';end if;
 payload:=jsonb_build_object('event',p_event_id,'version',p_expected_version,'party',p_party_size,'action',p_action,'consent',p_consent);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,77));
 select * into existing from public.open_house_rsvp_changes where user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
  select * into rsvp from public.open_house_rsvps where id=existing.rsvp_id;
  return jsonb_build_object('id',rsvp.id,'status',rsvp.status,'party_size',rsvp.party_size,'version',rsvp.version);
 end if;
 select * into event from public.open_house_events where id=p_event_id for update;
 select * into rsvp from public.open_house_rsvps where event_id=p_event_id and user_id=caller for update;
 if event.id is null then raise exception 'Available event required' using errcode='42501';end if;
 if coalesce(rsvp.version,0)<>p_expected_version then raise exception 'Reservation changed; refresh' using errcode='40001';end if;
 if p_action='reserve' then
  select l.organization_id into org from public.listings l join public.open_house_management m on m.event_id=event.id and m.organization_id=l.organization_id where l.id=event.listing_id and l.status='published' and m.host_user_id is not null;
  if org is null or event.status<>'scheduled' or event.starts_at<=now()+interval '15 minutes' or event.capacity is null then raise exception 'Available hosted event required' using errcode='42501';end if;
  if p_party_size is null or p_party_size not between 1 and 6 or p_consent is distinct from true then raise exception 'Party size and attendance contact consent required' using errcode='22023';end if;
  if coalesce((select sum(party_size) from public.open_house_rsvps where event_id=event.id and status='going' and user_id<>caller),0)+p_party_size>event.capacity then raise exception 'Event capacity reached' using errcode='23505';end if;
  if exists(select 1 from public.open_house_rsvps r join public.open_house_events e on e.id=r.event_id where r.user_id=caller and r.event_id<>event.id and r.status='going' and e.status='scheduled' and tstzrange(e.starts_at,e.ends_at,'[)') && tstzrange(event.starts_at,event.ends_at,'[)')) then raise exception 'Another open house reservation overlaps' using errcode='23505';end if;
  if rsvp.id is null then
   if (select count(*) from public.open_house_rsvp_changes where user_id=caller and created_at>now()-interval '1 day')>=30 then raise exception 'Daily reservation limit reached' using errcode='22023';end if;
   insert into public.open_house_rsvps(event_id,organization_id,user_id,party_size,status) values(event.id,org,caller,p_party_size,'going') returning * into rsvp;
  else update public.open_house_rsvps set party_size=p_party_size,status='going',version=version+1,updated_at=now() where id=rsvp.id returning * into rsvp;end if;
 else
  if rsvp.id is null then raise exception 'Own reservation required' using errcode='42501';end if;
  if p_party_size is not null or p_consent is not null then raise exception 'Cancellation fields only' using errcode='22023';end if;
  update public.open_house_rsvps set status='cancelled',version=version+1,updated_at=now() where id=rsvp.id returning * into rsvp;
 end if;
 insert into public.open_house_rsvp_changes(rsvp_id,user_id,request_id,payload) values(rsvp.id,caller,p_request_id,payload);
 return jsonb_build_object('id',rsvp.id,'status',rsvp.status,'party_size',rsvp.party_size,'version',rsvp.version);
end $$;
revoke all on function private.reserve_open_house(uuid,uuid,integer,integer,text,boolean) from public,anon;
grant execute on function private.reserve_open_house(uuid,uuid,integer,integer,text,boolean) to authenticated;
create function public.reserve_open_house(p_event_id uuid,p_request_id uuid,p_expected_version integer,p_party_size integer,p_action text,p_consent boolean) returns jsonb language sql security invoker set search_path='' as $$select private.reserve_open_house(p_event_id,p_request_id,p_expected_version,p_party_size,p_action,p_consent);$$;
revoke all on function public.reserve_open_house(uuid,uuid,integer,integer,text,boolean) from public,anon;
grant execute on function public.reserve_open_house(uuid,uuid,integer,integer,text,boolean) to authenticated;
