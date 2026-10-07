-- Public availability contains no prospect identity, private address or host identity.
create table public.viewing_slots (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id),
 listing_id uuid not null references public.listings(id),
 request_id uuid not null,
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 state text not null default 'open' check(state in ('open','held','booked','closed')),
 hold_expires_at timestamptz,
 created_at timestamptz not null default now(),
 unique(organization_id,request_id),
 check(ends_at>starts_at),
 check((state='held')=(hold_expires_at is not null))
);
create index viewing_slots_listing_time_idx on public.viewing_slots(listing_id,starts_at);
create index viewing_slots_org_time_idx on public.viewing_slots(organization_id,starts_at);
alter table public.viewing_slots enable row level security;
revoke all on public.viewing_slots from anon,authenticated;
grant select on public.viewing_slots to anon,authenticated;
create policy "public sees available published viewing slots" on public.viewing_slots for select to anon,authenticated using (
 starts_at>now()+interval '30 minutes' and (state='open' or (state='held' and hold_expires_at<=now()))
 and exists(select 1 from public.listings where id=listing_id and status='published')
);
create policy "staff reads organization viewing calendar" on public.viewing_slots for select to authenticated using (
 organization_id in(select organization_id from public.staff_accounts where user_id=(select auth.uid()) and role in('admin','realtor','manager'))
);
create table private.viewing_slot_hosts (
 slot_id uuid primary key references public.viewing_slots(id),
 host_user_id uuid not null references auth.users(id)
);
create index viewing_slot_hosts_user_idx on private.viewing_slot_hosts(host_user_id);
alter table private.viewing_slot_hosts enable row level security;
revoke all on private.viewing_slot_hosts from public,anon,authenticated;

alter table public.viewings add column organization_id uuid references public.organizations(id),
 add column slot_id uuid references public.viewing_slots(id),
 add column request_id uuid,
 add column enquiry_id uuid references public.enquiries(id),
 add column ends_at timestamptz,
 add column hold_expires_at timestamptz,
 add column contact_name text,
 add column contact_email text,
 add column phone text,
 add column title_snapshot text,
 add column cancellation_reason text,
 add column consented_at timestamptz not null default now(),
 add column updated_at timestamptz not null default now();
update public.viewings v set organization_id=l.organization_id,title_snapshot=l.title from public.listings l where l.id=v.listing_id;
alter table public.viewings drop constraint viewings_status_check;
alter table public.viewings add constraint viewings_status_check check(status in('requested','confirmed','completed','cancelled','no_show','expired'));
create unique index viewings_active_slot_idx on public.viewings(slot_id) where status in('requested','confirmed');
create unique index viewings_user_request_idx on public.viewings(user_id,request_id);
create index viewings_org_time_idx on public.viewings(organization_id,requested_for);
create index viewings_user_time_idx on public.viewings(user_id,requested_for);
create index viewings_enquiry_idx on public.viewings(enquiry_id);
revoke insert,update,delete on public.viewings from authenticated;
drop policy "users request published viewings" on public.viewings;
create policy "staff reads organization viewings" on public.viewings for select to authenticated using (
 organization_id in(select organization_id from public.staff_accounts where user_id=(select auth.uid()) and role in('admin','realtor','manager'))
);

create table public.viewing_events (
 id uuid primary key default gen_random_uuid(),
 viewing_id uuid not null references public.viewings(id),
 actor_user_id uuid references auth.users(id),
 event_name text not null,
 status text not null,
 reason text not null default '',
 created_at timestamptz not null default now()
);
create index viewing_events_viewing_idx on public.viewing_events(viewing_id,created_at);
alter table public.viewing_events enable row level security;
revoke all on public.viewing_events from anon,authenticated;
grant select on public.viewing_events to authenticated;
create policy "read history for accessible viewings" on public.viewing_events for select to authenticated using(exists(select 1 from public.viewings where id=viewing_id));

-- Extend the existing durable queue with immutable viewing event messages.
alter table private.notification_outbox drop constraint notification_outbox_state_check;
alter table private.notification_outbox add constraint notification_outbox_state_check check(state in('pending','processing','sent','failed','superseded'));
alter table private.notification_outbox alter column enquiry_id drop not null;
alter table private.notification_outbox add column viewing_event_id uuid references public.viewing_events(id),
 add column audience text not null default 'business' check(audience in('business','prospect')),
 add column subject_snapshot text,
 add column text_snapshot text,
 add constraint notification_outbox_entity check(num_nonnulls(enquiry_id,viewing_event_id)=1),
 add constraint notification_viewing_audience_unique unique(viewing_event_id,audience);

create function private.record_viewing_event(p_viewing_id uuid,p_event text,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); booking public.viewings; event_id uuid; details text;
begin
 if caller is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into booking from public.viewings where id=p_viewing_id;
 if booking.id is null or (booking.user_id<>caller and not exists(select 1 from public.staff_accounts where user_id=caller and organization_id=booking.organization_id and role in('admin','realtor','manager')) and not (p_event='hold_expired' and booking.status='expired' and booking.hold_expires_at<=now())) then raise exception 'Viewing access required' using errcode='42501'; end if;
 insert into public.viewing_events(viewing_id,actor_user_id,event_name,status,reason) values(booking.id,case when p_event='hold_expired' then null else caller end,p_event,booking.status,coalesce(p_reason,'')) returning id into event_id;
 update private.notification_outbox set state='superseded',last_error='Superseded by a newer viewing status' where state='pending' and viewing_event_id in(select id from public.viewing_events where viewing_id=booking.id and id<>event_id);
 details:='Event recorded (Jamaica): '||to_char(now() at time zone 'America/Jamaica','DD Mon YYYY HH12:MI AM')||E'\nViewing reference: '||booking.id::text||E'\nProperty: '||booking.title_snapshot||E'\nStatus: '||booking.status||E'\nTime (Jamaica): '||to_char(booking.requested_for at time zone 'America/Jamaica','DD Mon YYYY HH12:MI AM')||' to '||to_char(booking.ends_at at time zone 'America/Jamaica','HH12:MI AM')||E'\n'||case when booking.status='requested' then 'This request is not a confirmed appointment. Wait for staff confirmation.' else 'Review the current appointment status in your Open House account.' end||case when coalesce(p_reason,'')<>'' then E'\nReason: '||p_reason else '' end;
 insert into private.notification_outbox(viewing_event_id,audience,target_title,subject_snapshot,text_snapshot,recipient) values(event_id,'prospect',booking.title_snapshot,'Viewing '||booking.status||': '||booking.title_snapshot,details,booking.contact_email);
 insert into private.notification_outbox(viewing_event_id,audience,target_title,subject_snapshot,text_snapshot) values(event_id,'business',booking.title_snapshot,'Viewing '||booking.status||': '||booking.title_snapshot,details||E'\nProspect: '||booking.contact_name||E'\nEmail: '||booking.contact_email||E'\nPhone: '||coalesce(booking.phone,''));
end $$;
revoke all on function private.record_viewing_event(uuid,text,text) from public,anon,authenticated;

create function private.manage_viewing_slot(p_action text,p_request_id uuid,p_slot_id uuid,p_listing_id uuid,p_starts_at timestamptz,p_ends_at timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); org uuid; listing_org uuid; existing public.viewing_slots; created uuid;
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) then raise exception 'Verified identity required' using errcode='42501'; end if;
 select organization_id into org from public.staff_accounts where user_id=caller and role in('admin','realtor','manager');
 if org is null then raise exception 'Staff access required' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,71));
 if p_action='close' then
  select * into existing from public.viewing_slots where id=p_slot_id and organization_id=org for update;
  if existing.id is null then raise exception 'Slot unavailable' using errcode='22023'; end if;
  if existing.state in('held','booked') then raise exception 'Cancel or resolve the existing viewing before closing its slot' using errcode='P0001'; end if;
  update public.viewing_slots set state='closed',hold_expires_at=null where id=existing.id;
  return existing.id;
 elsif p_action<>'create' or p_action is null then raise exception 'Invalid slot action' using errcode='22023'; end if;
 if p_request_id is null or p_starts_at is null or p_ends_at is null or p_starts_at<now()+interval '30 minutes' or p_starts_at>now()+interval '120 days' or p_ends_at-p_starts_at not between interval '15 minutes' and interval '2 hours' then raise exception 'Invalid viewing window' using errcode='22023'; end if;
 select organization_id into listing_org from public.listings where id=p_listing_id;
 if listing_org is distinct from org then raise exception 'Organization listing required' using errcode='42501'; end if;
 select * into existing from public.viewing_slots where organization_id=org and request_id=p_request_id;
 if existing.id is not null then
  if existing.listing_id<>p_listing_id or existing.starts_at<>p_starts_at or existing.ends_at<>p_ends_at then raise exception 'Request ID already used' using errcode='22023'; end if;
  return existing.id;
 end if;
 if exists(select 1 from public.viewing_slots s left join private.viewing_slot_hosts h on h.slot_id=s.id where s.state<>'closed' and tstzrange(s.starts_at,s.ends_at,'[)') && tstzrange(p_starts_at,p_ends_at,'[)') and (s.listing_id=p_listing_id or h.host_user_id=caller)) then raise exception 'This property or host already has an overlapping slot' using errcode='P0001'; end if;
 insert into public.viewing_slots(organization_id,listing_id,request_id,starts_at,ends_at) values(org,p_listing_id,p_request_id,p_starts_at,p_ends_at) returning id into created;
 insert into private.viewing_slot_hosts(slot_id,host_user_id) values(created,caller);
 return created;
end $$;
revoke all on function private.manage_viewing_slot(text,uuid,uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function private.manage_viewing_slot(text,uuid,uuid,uuid,timestamptz,timestamptz) to authenticated;
create function public.manage_viewing_slot(p_action text,p_request_id uuid,p_slot_id uuid,p_listing_id uuid,p_starts_at timestamptz,p_ends_at timestamptz)
returns uuid language sql security invoker set search_path='' as $$select private.manage_viewing_slot(p_action,p_request_id,p_slot_id,p_listing_id,p_starts_at,p_ends_at);$$;
revoke all on function public.manage_viewing_slot(text,uuid,uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.manage_viewing_slot(text,uuid,uuid,uuid,timestamptz,timestamptz) to authenticated;

create function private.request_viewing(p_request_id uuid,p_slot_id uuid,p_enquiry_id uuid,p_contact_name text,p_phone text,p_consent boolean)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); email_address text; slot public.viewing_slots; existing public.viewings; expired public.viewings; title text; created uuid;
begin
 if caller is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select email into email_address from auth.users where id=caller and email_confirmed_at is not null;
 if email_address is null then raise exception 'Verified email required' using errcode='42501'; end if;
 if p_request_id is null or p_slot_id is null or p_consent is distinct from true or p_contact_name is null or length(trim(p_contact_name)) not between 2 and 120 or p_phone is null or length(p_phone)>40 then raise exception 'Invalid viewing request' using errcode='22023'; end if;
 -- Caller lock before slot lock serializes the prospect's overlapping reservations.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,72));
 select * into existing from public.viewings where user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.slot_id<>p_slot_id or existing.enquiry_id is distinct from p_enquiry_id or existing.contact_name<>trim(p_contact_name) or existing.phone<>trim(p_phone) then raise exception 'Request ID already used' using errcode='22023'; end if;
  return existing.id;
 end if;
 select * into slot from public.viewing_slots where id=p_slot_id for update;
 if slot.id is null or slot.starts_at<=now()+interval '30 minutes' or slot.state='closed' then raise exception 'Viewing slot unavailable' using errcode='P0001'; end if;
 select l.title into title from public.listings l where l.id=slot.listing_id and l.status='published';
 if title is null then raise exception 'Property unavailable' using errcode='22023'; end if;
 if p_enquiry_id is not null and not exists(select 1 from public.enquiries where id=p_enquiry_id and user_id=caller and listing_id=slot.listing_id) then raise exception 'Enquiry ownership required' using errcode='42501'; end if;
 -- Expire abandoned holds under the same slot lock before checking capacity.
 if slot.state='held' and slot.hold_expires_at<=now() then
  for expired in select * from public.viewings where slot_id=slot.id and status='requested' and hold_expires_at<=now() for update loop
   update public.viewings set status='expired',updated_at=now() where id=expired.id;
   -- System expiry never exposes the next prospect's identity to the prior one.
   perform private.record_viewing_event(expired.id,'hold_expired','The confirmation window elapsed.');
  end loop;
  update public.viewing_slots set state='open',hold_expires_at=null where id=slot.id;
  slot.state:='open';
 end if;
 if slot.state<>'open' or exists(select 1 from public.viewings where slot_id=slot.id and status in('requested','confirmed')) then raise exception 'Viewing slot no longer available' using errcode='P0001'; end if;
 if (select count(*) from public.viewings where user_id=caller and created_at>now()-interval '1 day')>=5 or (select count(*) from public.viewings where user_id=caller and requested_for>now() and (status='confirmed' or (status='requested' and hold_expires_at>now())))>=3 then raise exception 'Viewing request limit reached' using errcode='P0001'; end if;
 if exists(select 1 from public.viewings where user_id=caller and (status='confirmed' or (status='requested' and hold_expires_at>now())) and tstzrange(requested_for,ends_at,'[)') && tstzrange(slot.starts_at,slot.ends_at,'[)')) then raise exception 'You already have an overlapping viewing' using errcode='P0001'; end if;
 insert into public.viewings(user_id,organization_id,listing_id,slot_id,request_id,enquiry_id,requested_for,ends_at,hold_expires_at,contact_name,contact_email,phone,title_snapshot) values(caller,slot.organization_id,slot.listing_id,slot.id,p_request_id,p_enquiry_id,slot.starts_at,slot.ends_at,least(now()+interval '24 hours',slot.starts_at-interval '15 minutes'),trim(p_contact_name),email_address,trim(p_phone),title) returning id into created;
 update public.viewing_slots set state='held',hold_expires_at=least(now()+interval '24 hours',slot.starts_at-interval '15 minutes') where id=slot.id;
 perform private.record_viewing_event(created,'requested','');
 return created;
end $$;
revoke all on function private.request_viewing(uuid,uuid,uuid,text,text,boolean) from public,anon;
grant execute on function private.request_viewing(uuid,uuid,uuid,text,text,boolean) to authenticated;
create function public.request_viewing(p_request_id uuid,p_slot_id uuid,p_enquiry_id uuid,p_contact_name text,p_phone text,p_consent boolean)
returns uuid language sql security invoker set search_path='' as $$select private.request_viewing(p_request_id,p_slot_id,p_enquiry_id,p_contact_name,p_phone,p_consent);$$;
revoke all on function public.request_viewing(uuid,uuid,uuid,text,text,boolean) from public,anon;
grant execute on function public.request_viewing(uuid,uuid,uuid,text,text,boolean) to authenticated;

create function private.transition_viewing(p_viewing_id uuid,p_action text,p_reason text)
returns text language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); booking public.viewings; slot public.viewing_slots; staff boolean; next_status text;
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) then raise exception 'Verified identity required' using errcode='42501'; end if;
 -- Always lock the slot before its booking, matching request capacity checks.
 select * into booking from public.viewings where id=p_viewing_id;
 if booking.id is null then raise exception 'Viewing unavailable' using errcode='22023'; end if;
 staff:=exists(select 1 from public.staff_accounts where user_id=caller and organization_id=booking.organization_id and role in('admin','realtor','manager'));
 if booking.user_id<>caller and not staff then raise exception 'Viewing access required' using errcode='42501'; end if;
 if booking.slot_id is null then raise exception 'Legacy viewing needs staff review' using errcode='22023'; end if;
 select * into slot from public.viewing_slots where id=booking.slot_id for update;
 select * into booking from public.viewings where id=p_viewing_id for update;
 if p_action='confirm' and not staff then raise exception 'Staff confirmation required' using errcode='42501'; end if;
 if p_action in('complete','no_show') and not staff then raise exception 'Staff resolution required' using errcode='42501'; end if;
 if p_reason is null or length(p_reason)>500 then raise exception 'Invalid reason' using errcode='22023'; end if;
 if booking.status='requested' and booking.hold_expires_at<=now() then
  update public.viewings set status='expired',updated_at=now() where id=booking.id;
  update public.viewing_slots set state='open',hold_expires_at=null where id=slot.id;
  perform private.record_viewing_event(booking.id,'hold_expired','The confirmation window elapsed.');
  return 'expired';
 end if;
 if (p_action='confirm' and booking.status='confirmed') or (p_action='cancel' and booking.status='cancelled') or (p_action='complete' and booking.status='completed') or (p_action='no_show' and booking.status='no_show') then return booking.status; end if;
 if p_action='confirm' then
  if booking.status<>'requested' or slot.state<>'held' or slot.starts_at<=now() then raise exception 'Viewing cannot be confirmed' using errcode='P0001'; end if;
  next_status:='confirmed';
 elsif p_action='cancel' then
  if booking.status not in('requested','confirmed') or (not staff and booking.requested_for<=now()) or length(trim(p_reason))<5 then raise exception 'Cancellation requires an active viewing and a reason' using errcode='P0001'; end if;
  next_status:='cancelled';
 elsif p_action in('complete','no_show') then
  if booking.status<>'confirmed' or booking.ends_at>now() then raise exception 'Resolve the viewing after its scheduled end' using errcode='P0001'; end if;
  next_status:=case when p_action='complete' then 'completed' else 'no_show' end;
 else raise exception 'Invalid viewing action' using errcode='22023'; end if;
 update public.viewings set status=next_status,hold_expires_at=null,cancellation_reason=case when next_status='cancelled' then trim(p_reason) else cancellation_reason end,updated_at=now() where id=booking.id;
 update public.viewing_slots set state=case when next_status='confirmed' then 'booked' when next_status='cancelled' and starts_at>now() then 'open' else 'closed' end,hold_expires_at=null where id=slot.id;
 perform private.record_viewing_event(booking.id,p_action,trim(p_reason));
 return next_status;
end $$;
revoke all on function private.transition_viewing(uuid,text,text) from public,anon;
grant execute on function private.transition_viewing(uuid,text,text) to authenticated;
create function public.transition_viewing(p_viewing_id uuid,p_action text,p_reason text)
returns text language sql security invoker set search_path='' as $$select private.transition_viewing(p_viewing_id,p_action,p_reason);$$;
revoke all on function public.transition_viewing(uuid,text,text) from public,anon;
grant execute on function public.transition_viewing(uuid,text,text) to authenticated;

-- Reuse the queue worker for both enquiry and viewing event notifications.
drop function public.claim_enquiry_notifications(text,text);
create function public.claim_enquiry_notifications(p_sender text,p_recipient text) returns table(outbox_id uuid,enquiry_id uuid,lease_token uuid,contact_name text,contact_email text,phone text,message text,target_title text,sender text,recipient text,subject_snapshot text,text_snapshot text)
language plpgsql security invoker set search_path='' as $$
begin
 if p_sender is null or p_recipient is null or length(p_sender) not between 3 and 320 or length(p_recipient) not between 3 and 254 or p_sender ~ '[\r\n]' or p_recipient ~ '[\r\n]' then raise exception 'Invalid sender configuration' using errcode='22023'; end if;
 update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where state='processing' and attempts>=6 and lease_expires_at<now();
 update private.notification_outbox set state='failed',last_error='Delivery uncertain beyond provider idempotency window; manual review required' where state in('pending','processing') and first_attempt_at<now()-interval '23 hours';
 return query with candidates as (
  select o.id from private.notification_outbox o where o.attempts<6 and ((o.state='pending' and o.available_at<=now()) or (o.state='processing' and o.lease_expires_at<now())) order by o.created_at for update skip locked limit 5
 ), claimed as (
  update private.notification_outbox o set state='processing',attempts=o.attempts+1,lease_token=gen_random_uuid(),lease_expires_at=now()+interval '5 minutes',first_attempt_at=coalesce(o.first_attempt_at,now()),sender=coalesce(o.sender,p_sender),recipient=coalesce(o.recipient,p_recipient) from candidates c where o.id=c.id returning o.*
 ) select c.id,e.id,c.lease_token,coalesce(e.contact_name,''),coalesce(e.contact_email,''),coalesce(e.phone,''),coalesce(e.message,''),c.target_title,c.sender,c.recipient,c.subject_snapshot,c.text_snapshot from claimed c left join public.enquiries e on e.id=c.enquiry_id;
end $$;
revoke all on function public.claim_enquiry_notifications(text,text) from public,anon,authenticated;
grant execute on function public.claim_enquiry_notifications(text,text) to service_role;
