alter table public.open_house_rsvps add column title_snapshot text,add column area_snapshot text,add column starts_at_snapshot timestamptz,add column ends_at_snapshot timestamptz;
-- Existing reservations capture the currently available event details at migration time.
update public.open_house_rsvps r set title_snapshot=e.title,area_snapshot=l.area,starts_at_snapshot=e.starts_at,ends_at_snapshot=e.ends_at from public.open_house_events e join public.listings l on l.id=e.listing_id where r.event_id=e.id;
alter table public.open_house_rsvps alter column title_snapshot set not null,alter column area_snapshot set not null,alter column starts_at_snapshot set not null,alter column ends_at_snapshot set not null;
create function private.capture_open_house_reservation_history() returns trigger language plpgsql security definer set search_path='' as $$
declare event public.open_house_events;listing public.listings;
begin
 if tg_op='INSERT' then
  select * into event from public.open_house_events where id=new.event_id for share;
  select * into listing from public.listings where id=event.listing_id for share;
  if event.id is null or listing.id is null or new.organization_id<>listing.organization_id then raise exception 'Event organization required' using errcode='42501';end if;
  new.title_snapshot:=event.title;new.area_snapshot:=listing.area;new.starts_at_snapshot:=event.starts_at;new.ends_at_snapshot:=event.ends_at;
 elsif row(new.event_id,new.organization_id,new.user_id,new.title_snapshot,new.area_snapshot,new.starts_at_snapshot,new.ends_at_snapshot) is distinct from row(old.event_id,old.organization_id,old.user_id,old.title_snapshot,old.area_snapshot,old.starts_at_snapshot,old.ends_at_snapshot) then
  raise exception 'Reservation identity and event history are immutable' using errcode='22023';
 end if;
 return new;
end $$;
revoke all on function private.capture_open_house_reservation_history() from public,anon,authenticated;
create trigger capture_open_house_reservation_history before insert or update on public.open_house_rsvps for each row execute function private.capture_open_house_reservation_history();
