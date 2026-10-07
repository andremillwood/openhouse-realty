create or replace function private.queue_open_house_event_notices() returns trigger language plpgsql security definer set search_path='' as $$
declare r record;kind text;source uuid;scope_org uuid;
begin
 if tg_table_name='open_house_events' then
  if new.status<>'cancelled' or old.status='cancelled' then return new;end if;kind:='event_cancelled';source:=new.id;select organization_id into scope_org from public.open_house_management where event_id=new.id;
  for r in select id from public.open_house_rsvps where event_id=new.id and status='going' loop perform private.queue_open_house_notice(r.id,kind,source);end loop;
 elsif tg_table_name='listings' then
  if new.status='published' and old.status<>'published' then
   update private.notification_outbox o set state='superseded',last_error='Listing available again',lease_token=null,lease_expires_at=null where o.state in('pending','processing') and o.open_house_notice_id in(select n.id from private.open_house_notices n join public.open_house_rsvps r on r.id=n.rsvp_id join public.open_house_events e on e.id=r.event_id where n.kind='unavailable' and e.listing_id=new.id and n.organization_id=new.organization_id);
  end if;
  if old.status<>'published' or new.status='published' then return new;end if;kind:='unavailable';source:=gen_random_uuid();scope_org:=new.organization_id;
  for r in select r.id from public.open_house_rsvps r join public.open_house_events e on e.id=r.event_id where e.listing_id=new.id and e.status='scheduled' and e.ends_at>now() and r.status='going' loop perform private.queue_open_house_notice(r.id,kind,source);end loop;
 else
  scope_org:=new.organization_id;
  for r in select id from public.open_house_rsvps where event_id=new.event_id and status='going' loop perform private.queue_open_house_notice(r.id,'arrival_updated',new.id);end loop;
 end if;
 update private.notification_outbox o set state='superseded',last_error='Open house notice no longer current',lease_token=null,lease_expires_at=null where o.organization_id=scope_org and o.open_house_notice_id is not null and o.state in('pending','processing') and not private.open_house_notice_current(o.open_house_notice_id);
 return new;
end $$;
