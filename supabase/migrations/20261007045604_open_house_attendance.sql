alter table public.open_house_rsvps add column attendance_state text not null default 'unrecorded' check(attendance_state in('unrecorded','attended','no_show')),add column attended_count integer not null default 0,add column attendance_version integer not null default 0 check(attendance_version>=0),add constraint open_house_attendance_count check((attendance_state='attended' and attended_count between 1 and party_size) or (attendance_state<>'attended' and attended_count=0));
create table public.open_house_attendance_changes (
 id uuid primary key default gen_random_uuid(),rsvp_id uuid not null references public.open_house_rsvps(id),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,version integer not null,state text not null,attended_count integer not null,reason text not null,payload jsonb not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index open_house_attendance_changes_org_idx on public.open_house_attendance_changes(organization_id,created_at desc);
create index open_house_attendance_changes_rsvp_idx on public.open_house_attendance_changes(rsvp_id,created_at desc);
alter table public.open_house_attendance_changes enable row level security;
revoke all on public.open_house_attendance_changes from public,anon,authenticated;
grant select on public.open_house_attendance_changes to authenticated;
grant select,insert on public.open_house_attendance_changes to service_role;
create policy "verified staff read organization attendance audit" on public.open_house_attendance_changes for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));
create function private.guard_recorded_attendance_reservation() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.attendance_state<>'unrecorded' and row(new.party_size,new.status) is distinct from row(old.party_size,old.status) then raise exception 'Staff must correct attendance before changing this reservation' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.guard_recorded_attendance_reservation() from public,anon,authenticated;
create trigger guard_recorded_attendance_reservation before update on public.open_house_rsvps for each row execute function private.guard_recorded_attendance_reservation();
create function private.record_open_house_attendance(p_rsvp_id uuid,p_request_id uuid,p_rsvp_version integer,p_attendance_version integer,p_state text,p_attended_count integer,p_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();rsvp public.open_house_rsvps;event public.open_house_events;existing public.open_house_attendance_changes;payload jsonb;
begin
 if caller is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_rsvp_id is null or p_request_id is null or p_rsvp_version is null or p_rsvp_version<1 or p_attendance_version is null or p_attendance_version not between 0 and 2147483646 or p_state is null or p_state not in('unrecorded','attended','no_show') or p_attended_count is null or p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'Valid attendance details and reason required' using errcode='22023';end if;
 payload:=jsonb_build_object('rsvp',p_rsvp_id,'rsvp_version',p_rsvp_version,'attendance_version',p_attendance_version,'state',p_state,'count',p_attended_count,'reason',trim(p_reason));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,71));
 select * into existing from public.open_house_attendance_changes where actor_user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.organization_id<>org or existing.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
  select * into rsvp from public.open_house_rsvps where id=existing.rsvp_id;
  return jsonb_build_object('attendance_state',rsvp.attendance_state,'attended_count',rsvp.attended_count,'attendance_version',rsvp.attendance_version);
 end if;
 select * into rsvp from public.open_house_rsvps where id=p_rsvp_id and organization_id=org;
 if rsvp.id is null then raise exception 'Organization reservation required' using errcode='42501';end if;
 select e.* into event from public.open_house_events e join public.open_house_management m on m.event_id=e.id where e.id=rsvp.event_id and m.organization_id=org for update of e;
 select * into rsvp from public.open_house_rsvps where id=p_rsvp_id for update;
 if event.id is null or rsvp.organization_id<>org then raise exception 'Organization event required' using errcode='42501';end if;
 if rsvp.version<>p_rsvp_version or rsvp.attendance_version<>p_attendance_version then raise exception 'Reservation or attendance changed; refresh' using errcode='40001';end if;
 if rsvp.status<>'going' or now()<event.starts_at-interval '30 minutes' or now()>event.ends_at+interval '7 days' or (event.status='cancelled' and p_state<>'unrecorded') or (p_state='no_show' and now()<event.ends_at) or (p_state='unrecorded' and rsvp.attendance_state='unrecorded') then raise exception 'Attendance window or event state invalid' using errcode='22023';end if;
 if (p_state='attended' and p_attended_count not between 1 and rsvp.party_size) or (p_state<>'attended' and p_attended_count<>0) then raise exception 'Attendance cannot exceed the reserved party' using errcode='22023';end if;
 update public.open_house_rsvps set attendance_state=p_state,attended_count=p_attended_count,attendance_version=attendance_version+1 where id=rsvp.id returning * into rsvp;
 insert into public.open_house_attendance_changes(rsvp_id,organization_id,actor_user_id,request_id,version,state,attended_count,reason,payload) values(rsvp.id,org,caller,p_request_id,rsvp.attendance_version,p_state,p_attended_count,trim(p_reason),payload);
 return jsonb_build_object('attendance_state',rsvp.attendance_state,'attended_count',rsvp.attended_count,'attendance_version',rsvp.attendance_version);
end $$;
revoke all on function private.record_open_house_attendance(uuid,uuid,integer,integer,text,integer,text) from public,anon;
grant execute on function private.record_open_house_attendance(uuid,uuid,integer,integer,text,integer,text) to authenticated;
create function public.record_open_house_attendance(p_rsvp_id uuid,p_request_id uuid,p_rsvp_version integer,p_attendance_version integer,p_state text,p_attended_count integer,p_reason text) returns jsonb language sql security invoker set search_path='' as $$select private.record_open_house_attendance(p_rsvp_id,p_request_id,p_rsvp_version,p_attendance_version,p_state,p_attended_count,p_reason);$$;
revoke all on function public.record_open_house_attendance(uuid,uuid,integer,integer,text,integer,text) from public,anon;
grant execute on function public.record_open_house_attendance(uuid,uuid,integer,integer,text,integer,text) to authenticated;

create or replace function private.open_house_staff_roster(p_event_id uuid,p_state text,p_page integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid:=private.verified_enquiry_staff_organization();event public.open_house_events;total integer;page integer;pages integer;rows jsonb;reserved integer;going integer;cancelled integer;
begin
 if auth.uid() is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_event_id is null or p_state is null or p_state not in('going','cancelled','all') or p_page is null or p_page not between 1 and 100000 then raise exception 'Valid event/state/page required' using errcode='22023';end if;
 select e.* into event from public.open_house_events e join public.open_house_management m on m.event_id=e.id where e.id=p_event_id and m.organization_id=org;
 if event.id is null then raise exception 'Organization event required' using errcode='42501';end if;
 select count(*) into total from public.open_house_rsvps where event_id=event.id and organization_id=org and (p_state='all' or status=p_state);
 pages:=greatest(1,(total+24)/25);page:=least(p_page,pages);
 select coalesce(sum(party_size) filter(where status='going'),0),count(*) filter(where status='going'),count(*) filter(where status='cancelled') into reserved,going,cancelled from public.open_house_rsvps where event_id=event.id and organization_id=org;
 select coalesce(jsonb_agg(to_jsonb(row) order by row.created_at,row.id),'[]'::jsonb) into rows from (
  select r.id,r.party_size,r.status,r.version,r.attendance_state,r.attended_count,r.attendance_version,r.created_at,case when u.email_confirmed_at is not null then u.email else null end as contact_email from public.open_house_rsvps r join auth.users u on u.id=r.user_id where r.event_id=event.id and r.organization_id=org and (p_state='all' or r.status=p_state) order by r.created_at,r.id limit 25 offset (page-1)*25
 ) row;
 return jsonb_build_object('event',jsonb_build_object('id',event.id,'title',event.title,'starts_at',event.starts_at,'ends_at',event.ends_at,'capacity',event.capacity,'status',event.status),'page',page,'pages',pages,'total',total,'reserved_places',reserved,'going_parties',going,'cancelled_parties',cancelled,'rows',rows);
end $$;
