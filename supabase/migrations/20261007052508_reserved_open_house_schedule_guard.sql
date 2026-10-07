create function private.guard_reserved_open_house_schedule() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if row(new.listing_id,new.starts_at,new.ends_at) is distinct from row(old.listing_id,old.starts_at,old.ends_at)
 and exists(select 1 from public.open_house_rsvps where event_id=old.id) then
 raise exception 'Cancel this event and create a new event to change a reserved schedule' using errcode='23505';
 end if;
 return new;
end $$;
revoke all on function private.guard_reserved_open_house_schedule() from public,anon,authenticated;
create trigger guard_reserved_open_house_schedule before update of listing_id,starts_at,ends_at on public.open_house_events for each row execute function private.guard_reserved_open_house_schedule();
