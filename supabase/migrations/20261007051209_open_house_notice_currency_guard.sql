create or replace function private.open_house_notice_current(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.open_house_notices n join public.open_house_rsvps r on r.id=n.rsvp_id join public.open_house_events e on e.id=r.event_id join public.listings l on l.id=e.listing_id join auth.users u on u.id=r.user_id where n.id=p_id and n.organization_id=r.organization_id and r.organization_id=l.organization_id and n.rsvp_version=r.version and n.expires_at>now() and u.email_confirmed_at is not null and lower(u.email)=lower(n.recipient) and (
 (n.kind in('reservation','reminder') and r.status='going' and r.attendance_state='unrecorded' and e.status='scheduled' and e.starts_at>now() and l.status='published') or
 (n.kind='arrival_updated' and n.source_id=(select id from public.open_house_arrival_changes where event_id=e.id order by version desc limit 1) and r.status='going' and e.status='scheduled' and e.ends_at>now() and l.status='published') or
 (n.kind='rsvp_cancelled' and r.status='cancelled') or
 (n.kind='event_cancelled' and r.status='going' and e.status='cancelled') or
 (n.kind='unavailable' and r.status='going' and e.status='scheduled' and e.ends_at>now() and l.status<>'published')
 ));
$$;

create or replace function private.queue_open_house_event_notices() returns trigger language plpgsql security definer set search_path='' as $$
declare r record;kind text;source uuid;scope_org uuid;
begin
 if tg_table_name='open_house_events' then
  if new.status<>'cancelled' or old.status='cancelled' then return new;end if;kind:='event_cancelled';source:=new.id;select organization_id into scope_org from public.open_house_management where event_id=new.id;
  for r in select id from public.open_house_rsvps where event_id=new.id and status='going' loop perform private.queue_open_house_notice(r.id,kind,source);end loop;
 elsif tg_table_name='listings' then
  if old.status<>'published' or new.status='published' then return new;end if;kind:='unavailable';source:=gen_random_uuid();scope_org:=new.organization_id;
  for r in select r.id from public.open_house_rsvps r join public.open_house_events e on e.id=r.event_id where e.listing_id=new.id and e.status='scheduled' and e.ends_at>now() and r.status='going' loop perform private.queue_open_house_notice(r.id,kind,source);end loop;
 else
  scope_org:=new.organization_id;
  for r in select id from public.open_house_rsvps where event_id=new.event_id and status='going' loop perform private.queue_open_house_notice(r.id,'arrival_updated',new.id);end loop;
 end if;
 update private.notification_outbox o set state='superseded',last_error='Open house notice no longer current',lease_token=null,lease_expires_at=null where o.organization_id=scope_org and o.open_house_notice_id is not null and o.state in('pending','processing') and not private.open_house_notice_current(o.open_house_notice_id);
 return new;
end $$;
