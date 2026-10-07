create table private.open_house_notices (
 id uuid primary key default gen_random_uuid(),rsvp_id uuid not null references public.open_house_rsvps(id),organization_id uuid not null references public.organizations(id),kind text not null check(kind in('reservation','reminder','rsvp_cancelled','event_cancelled','unavailable','arrival_updated')),source_id uuid not null,rsvp_version integer not null,recipient text not null,expires_at timestamptz not null,unique(rsvp_id,kind,source_id)
);
create index open_house_notices_org_idx on private.open_house_notices(organization_id);
alter table private.open_house_notices enable row level security;
revoke all on private.open_house_notices from public,anon,authenticated;
grant select,insert on private.open_house_notices to service_role;
alter table private.notification_outbox add column open_house_notice_id uuid references private.open_house_notices(id);
alter table private.notification_outbox drop constraint notification_outbox_entity;
alter table private.notification_outbox add constraint notification_outbox_entity check(num_nonnulls(enquiry_id,viewing_event_id,seller_lead_id,application_event_id,cosigner_id,open_house_notice_id)=1);
create unique index notification_outbox_open_house_idx on private.notification_outbox(open_house_notice_id) where open_house_notice_id is not null;
create function private.open_house_notice_current(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.open_house_notices n join public.open_house_rsvps r on r.id=n.rsvp_id join public.open_house_events e on e.id=r.event_id join public.listings l on l.id=e.listing_id join auth.users u on u.id=r.user_id where n.id=p_id and n.organization_id=r.organization_id and r.organization_id=l.organization_id and n.rsvp_version=r.version and n.expires_at>now() and u.email_confirmed_at is not null and lower(u.email)=lower(n.recipient) and (
 (n.kind in('reservation','reminder') and r.status='going' and r.attendance_state='unrecorded' and e.status='scheduled' and e.starts_at>now() and l.status='published') or
 (n.kind='arrival_updated' and r.status='going' and e.status='scheduled' and e.ends_at>now() and l.status='published') or
 (n.kind='rsvp_cancelled' and r.status='cancelled') or
 (n.kind='event_cancelled' and r.status='going' and e.status='cancelled') or
 (n.kind='unavailable' and r.status='going' and e.status='scheduled' and e.ends_at>now() and l.status<>'published')
 ));
$$;
revoke all on function private.open_house_notice_current(uuid) from public,anon,authenticated;
grant execute on function private.open_house_notice_current(uuid) to service_role;
create or replace function private.bind_notification_organization() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 new.organization_id:=coalesce((select organization_id from public.enquiries where id=new.enquiry_id),(select v.organization_id from public.viewing_events e join public.viewings v on v.id=e.viewing_id where e.id=new.viewing_event_id),(select organization_id from public.seller_leads where id=new.seller_lead_id),(select a.organization_id from public.rental_application_events e join public.rental_applications a on a.id=e.application_id where e.id=new.application_event_id),(select organization_id from public.application_cosigners where id=new.cosigner_id),(select organization_id from private.open_house_notices where id=new.open_house_notice_id));
 if new.organization_id is null then raise exception 'Notification organization unavailable' using errcode='22023';end if;return new;
end $$;
create function private.queue_open_house_notice(p_rsvp uuid,p_kind text,p_source uuid) returns void language plpgsql security definer set search_path='' as $$
declare r public.open_house_rsvps;e public.open_house_events;email text;notice uuid;subject text;body text;eligible timestamptz:=now();expiry timestamptz;
begin
 select * into r from public.open_house_rsvps where id=p_rsvp;select * into e from public.open_house_events where id=r.event_id;select u.email into email from auth.users u where u.id=r.user_id and u.email_confirmed_at is not null;
 if r.id is null or email is null or e.id is null then return;end if;
 if p_kind='reminder' and e.starts_at<=now()+interval '24 hours' then return;end if;
 if p_kind='rsvp_cancelled' and e.ends_at<=now() then return;end if;
 subject:=case p_kind when 'reservation' then 'Your Open House RSVP' when 'reminder' then 'Your open house is tomorrow' when 'rsvp_cancelled' then 'Your open-house RSVP is cancelled' when 'event_cancelled' then 'Your open house has been cancelled' when 'unavailable' then 'Your open house needs team confirmation' else 'Open-house arrival instructions changed' end;
 expiry:=case when p_kind in('reservation','reminder') then e.starts_at when p_kind in('arrival_updated','unavailable') then e.ends_at else now()+interval '7 days' end;
 if p_kind='reminder' then eligible:=e.starts_at-interval '24 hours';end if;
 insert into private.open_house_notices(rsvp_id,organization_id,kind,source_id,rsvp_version,recipient,expires_at) values(r.id,r.organization_id,p_kind,p_source,r.version,email,expiry) on conflict(rsvp_id,kind,source_id) do nothing returning id into notice;
 if notice is null then return;end if;
 body:=subject||E'\n\nEvent: '||r.title_snapshot||E'\nNeighborhood: '||r.area_snapshot||E'\nScheduled start: '||to_char(e.starts_at at time zone 'America/Jamaica','YYYY-MM-DD HH24:MI')||E' (Jamaica)\nParty size: '||r.party_size||E'\nReservation reference: '||r.id||E'\n\n'||case when p_kind in('event_cancelled','unavailable') then 'Do not travel to this event without updated confirmation from the Open House team.' when p_kind='rsvp_cancelled' then 'Your RSVP has been cancelled. Contact the team if you need assistance.' when p_kind='arrival_updated' then 'Approved arrival instructions have changed or been withdrawn. Review the current details and contact the team before travelling.' else 'Review your reservation and current approved arrival instructions before travelling.' end||E'\nPrivate meeting directions are available only in your verified account when eligible.\n\nManage your reservation: ';
 insert into private.notification_outbox(open_house_notice_id,audience,target_title,recipient,subject_snapshot,text_snapshot,action_path,available_at) values(notice,'prospect',r.title_snapshot,email,subject,body,'/account/open-houses',eligible);
end $$;
revoke all on function private.queue_open_house_notice(uuid,text,uuid) from public,anon,authenticated;
create function private.queue_open_house_rsvp_notices() returns trigger language plpgsql security definer set search_path='' as $$
declare r public.open_house_rsvps;
begin
 select * into r from public.open_house_rsvps where id=new.rsvp_id;
 if new.user_id is distinct from auth.uid() or r.user_id is distinct from new.user_id or not exists(select 1 from auth.users where id=new.user_id and email_confirmed_at is not null) then raise exception 'Verified reservation change required' using errcode='42501';end if;
 update private.notification_outbox o set state='superseded',last_error='Reservation changed',lease_token=null,lease_expires_at=null where o.state in('pending','processing') and o.open_house_notice_id in(select id from private.open_house_notices where rsvp_id=r.id);
 if r.status='going' then perform private.queue_open_house_notice(r.id,'reservation',new.id);perform private.queue_open_house_notice(r.id,'reminder',new.id);else perform private.queue_open_house_notice(r.id,'rsvp_cancelled',new.id);end if;
 return new;
end $$;
revoke all on function private.queue_open_house_rsvp_notices() from public,anon,authenticated;
create trigger queue_open_house_rsvp_notices after insert on public.open_house_rsvp_changes for each row execute function private.queue_open_house_rsvp_notices();
create function private.queue_open_house_event_notices() returns trigger language plpgsql security definer set search_path='' as $$
declare r record;kind text;source uuid;
begin
 if tg_table_name='open_house_events' then
  if new.status<>'cancelled' or old.status='cancelled' then return new;end if;kind:='event_cancelled';source:=new.id;
  for r in select id from public.open_house_rsvps where event_id=new.id and status='going' loop perform private.queue_open_house_notice(r.id,kind,source);end loop;
 elsif tg_table_name='listings' then
  if old.status<>'published' or new.status='published' then return new;end if;kind:='unavailable';source:=gen_random_uuid();
  for r in select r.id from public.open_house_rsvps r join public.open_house_events e on e.id=r.event_id where e.listing_id=new.id and e.status='scheduled' and e.ends_at>now() and r.status='going' loop perform private.queue_open_house_notice(r.id,kind,source);end loop;
 else
  for r in select id from public.open_house_rsvps where event_id=new.event_id and status='going' loop perform private.queue_open_house_notice(r.id,'arrival_updated',new.id);end loop;
 end if;
 update private.notification_outbox o set state='superseded',last_error='Open house notice no longer current',lease_token=null,lease_expires_at=null where o.open_house_notice_id is not null and o.state in('pending','processing') and not private.open_house_notice_current(o.open_house_notice_id);
 return new;
end $$;
revoke all on function private.queue_open_house_event_notices() from public,anon,authenticated;
create trigger queue_open_house_event_notices after update of status on public.open_house_events for each row execute function private.queue_open_house_event_notices();
create trigger queue_open_house_listing_notices after update of status on public.listings for each row execute function private.queue_open_house_event_notices();
create trigger queue_open_house_arrival_notices after insert on public.open_house_arrival_changes for each row execute function private.queue_open_house_event_notices();

create or replace function public.claim_enquiry_notifications(p_sender text,p_recipient text) returns table(outbox_id uuid,enquiry_id uuid,lease_token uuid,contact_name text,contact_email text,phone text,message text,target_title text,sender text,recipient text,subject_snapshot text,text_snapshot text)
language plpgsql security invoker set search_path='' as $$
begin
 update private.notification_outbox o set state='superseded',last_error='Open house notice expired or changed',lease_token=null,lease_expires_at=null where o.open_house_notice_id is not null and o.state in('pending','processing') and not private.open_house_notice_current(o.open_house_notice_id);
 if p_sender is null or p_recipient is null or length(p_sender) not between 3 and 320 or length(p_recipient) not between 3 and 254 or p_sender ~ '[\r\n]' or p_recipient ~ '[\r\n]' then raise exception 'Invalid sender configuration' using errcode='22023'; end if;
 update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where state='processing' and attempts>=6 and lease_expires_at<now();
 update private.notification_outbox set state='failed',last_error='Delivery uncertain beyond provider idempotency window; manual review required' where state in('pending','processing') and first_attempt_at<now()-interval '23 hours';
 return query with candidates as (
  select o.id from private.notification_outbox o where o.cosigner_id is null and o.open_house_notice_id is null and o.attempts<6 and ((o.state='pending' and o.available_at<=now()) or (o.state='processing' and o.lease_expires_at<now())) order by o.created_at for update skip locked limit 5
 ), claimed as (
  update private.notification_outbox o set state='processing',attempts=o.attempts+1,lease_token=gen_random_uuid(),lease_expires_at=now()+interval '5 minutes',first_attempt_at=coalesce(o.first_attempt_at,now()),sender=coalesce(o.sender,p_sender),recipient=coalesce(o.recipient,p_recipient) from candidates c where o.id=c.id returning o.*
 ) select c.id,e.id,c.lease_token,coalesce(e.contact_name,''),coalesce(e.contact_email,''),coalesce(e.phone,''),coalesce(e.message,''),c.target_title,c.sender,c.recipient,c.subject_snapshot,c.text_snapshot from claimed c left join public.enquiries e on e.id=c.enquiry_id;
end $$;
revoke all on function public.claim_enquiry_notifications(text,text) from public,anon,authenticated;
grant execute on function public.claim_enquiry_notifications(text,text) to service_role;

create or replace function public.claim_transactional_notifications(p_sender text,p_recipient text,p_app_origin text) returns table(outbox_id uuid,enquiry_id uuid,lease_token uuid,contact_name text,contact_email text,phone text,message text,target_title text,sender text,recipient text,subject_snapshot text,text_snapshot text)
language plpgsql security invoker set search_path='' as $$
begin
 if p_app_origin is null or length(p_app_origin)>300 or p_app_origin !~ '^https://[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?(:[0-9]{1,5})?$' then raise exception 'Canonical HTTPS application origin required' using errcode='22023';end if;
 update private.notification_outbox o set state='superseded',last_error='Invitation expired or closed',lease_token=null,lease_expires_at=null where o.cosigner_id is not null and o.state in('pending','processing') and not exists(select 1 from public.application_cosigners c join public.rental_applications a on a.id=c.application_id where c.id=o.cosigner_id and c.state='pending' and c.expires_at>now() and a.status in('submitted','under_review','needs_info'));
 update private.notification_outbox o set state='superseded',last_error='Open house notice expired or changed',lease_token=null,lease_expires_at=null where o.open_house_notice_id is not null and o.state in('pending','processing') and not private.open_house_notice_current(o.open_house_notice_id);
 if p_sender is null or p_recipient is null or length(p_sender) not between 3 and 320 or length(p_recipient) not between 3 and 254 or p_sender ~ '[\r\n]' or p_recipient ~ '[\r\n]' then raise exception 'Invalid sender configuration' using errcode='22023'; end if;
 update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where state='processing' and attempts>=6 and lease_expires_at<now();
 update private.notification_outbox set state='failed',last_error='Delivery uncertain beyond provider idempotency window; manual review required' where state in('pending','processing') and first_attempt_at<now()-interval '23 hours';
 return query with candidates as (
  select o.id from private.notification_outbox o where o.attempts<6 and ((o.state='pending' and o.available_at<=now()) or (o.state='processing' and o.lease_expires_at<now())) order by o.created_at for update skip locked limit 5
 ), claimed as (
  update private.notification_outbox o set state='processing',attempts=o.attempts+1,lease_token=gen_random_uuid(),lease_expires_at=now()+interval '5 minutes',text_snapshot=case when o.action_path is not null and o.first_attempt_at is null then o.text_snapshot||p_app_origin||o.action_path else o.text_snapshot end,first_attempt_at=coalesce(o.first_attempt_at,now()),sender=coalesce(o.sender,p_sender),recipient=coalesce(o.recipient,p_recipient) from candidates c where o.id=c.id returning o.*
 ) select c.id,e.id,c.lease_token,coalesce(e.contact_name,''),coalesce(e.contact_email,''),coalesce(e.phone,''),coalesce(e.message,''),c.target_title,c.sender,c.recipient,c.subject_snapshot,c.text_snapshot from claimed c left join public.enquiries e on e.id=c.enquiry_id;
end $$;
revoke all on function public.claim_transactional_notifications(text,text,text) from public,anon,authenticated;
grant execute on function public.claim_transactional_notifications(text,text,text) to service_role;

create or replace function public.notification_attempt_current(p_id uuid,p_lease_token uuid) returns boolean language sql security invoker set search_path='' as $$
 select exists(select 1 from private.notification_outbox o where o.id=p_id and o.lease_token=p_lease_token and o.state='processing' and o.lease_expires_at>now() and (o.open_house_notice_id is null or private.open_house_notice_current(o.open_house_notice_id)) and (o.cosigner_id is null or exists(select 1 from public.application_cosigners c join public.rental_applications a on a.id=c.application_id where c.id=o.cosigner_id and c.state='pending' and c.expires_at>now() and a.status in('submitted','under_review','needs_info'))));
$$;
revoke all on function public.notification_attempt_current(uuid,uuid) from public,anon,authenticated;
grant execute on function public.notification_attempt_current(uuid,uuid) to service_role;

create or replace function private.staff_notification_monitor(p_state text,p_family text,p_page integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid:=private.verified_enquiry_staff_organization();result jsonb;
begin
 if auth.uid() is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_state is null or p_state not in('all','pending','processing','sent','failed','superseded') or p_family is null or p_family not in('all','enquiry','viewing','seller','application','cosigner','open_house') or p_page is null or p_page not between 1 and 99999 then raise exception 'Valid monitor filters and page required' using errcode='22023';end if;
 with scoped as materialized (
  select o.id,o.state,o.audience,o.target_title,o.attempts,o.created_at,o.available_at,o.first_attempt_at,o.sent_at,o.last_error,
   case when o.enquiry_id is not null then 'enquiry' when o.viewing_event_id is not null then 'viewing' when o.seller_lead_id is not null then 'seller' when o.application_event_id is not null then 'application' when o.cosigner_id is not null then 'cosigner' else 'open_house' end family
  from private.notification_outbox o where o.organization_id=org
 ), filtered as materialized (select * from scoped where (p_state='all' or state=p_state) and (p_family='all' or family=p_family)), totals as (
  select count(*) total,greatest(1,ceil(count(*)::numeric/25)::integer) pages from filtered
 ), page_rows as (
  select * from filtered order by created_at desc,id offset (select (least(p_page,pages)-1)*25 from totals) limit 25
 ) select jsonb_build_object('total',t.total,'pages',t.pages,'page',least(p_page,t.pages),'counts',(select coalesce(jsonb_object_agg(state,n),'{}'::jsonb) from(select state,count(*) n from scoped group by state)c),'rows',(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) from page_rows r)) into result from totals t;
 return result;
end $$;

create or replace function private.staff_notification_delivery_monitor(p_state text,p_family text,p_delivery text,p_page integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid:=private.verified_enquiry_staff_organization();result jsonb;
begin
 if auth.uid() is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_state is null or p_state not in('all','pending','processing','sent','failed','superseded') or p_family is null or p_family not in('all','enquiry','viewing','seller','application','cosigner','open_house') or p_delivery is null or p_delivery not in('all','unknown','sent','delivered','delayed','bounced','complained','failed','suppressed') or p_page is null or p_page not between 1 and 99999 then raise exception 'Valid monitor filters and page required' using errcode='22023';end if;
 with scoped as materialized (
  select o.id,o.state,o.audience,o.target_title,o.attempts,o.created_at,o.available_at,o.first_attempt_at,o.sent_at,o.last_error,o.delivery_state,o.delivery_event_at,
   case when o.enquiry_id is not null then 'enquiry' when o.viewing_event_id is not null then 'viewing' when o.seller_lead_id is not null then 'seller' when o.application_event_id is not null then 'application' when o.cosigner_id is not null then 'cosigner' else 'open_house' end family
  from private.notification_outbox o where o.organization_id=org
 ), filtered as materialized (select * from scoped where (p_state='all' or state=p_state) and (p_family='all' or family=p_family) and (p_delivery='all' or delivery_state=p_delivery)), totals as (
  select count(*) total,greatest(1,ceil(count(*)::numeric/25)::integer) pages from filtered
 ), page_rows as (
  select * from filtered order by created_at desc,id offset (select (least(p_page,pages)-1)*25 from totals) limit 25
 ) select jsonb_build_object('total',t.total,'pages',t.pages,'page',least(p_page,t.pages),'counts',(select coalesce(jsonb_object_agg(state,n),'{}'::jsonb) from(select state,count(*) n from scoped group by state)c),'delivery_counts',(select coalesce(jsonb_object_agg(delivery_state,n),'{}'::jsonb) from(select delivery_state,count(*) n from scoped group by delivery_state)d),'rows',(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) from page_rows r)) into result from totals t;
 return result;
end $$;

create or replace function private.reserve_open_house(p_event_id uuid,p_request_id uuid,p_expected_version integer,p_party_size integer,p_action text,p_consent boolean) returns jsonb language plpgsql security definer set search_path='' as $$
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
  if (select count(*) from public.open_house_rsvp_changes where user_id=caller and created_at>now()-interval '1 day')>=30 then raise exception 'Daily reservation limit reached' using errcode='22023';end if;
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
