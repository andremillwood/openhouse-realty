-- Whole-property appointments cover every unit; distinct units may run concurrently.
create function private.listing_resources_overlap(a public.listings,b public.listings) returns boolean language sql immutable security invoker set search_path='' as $$
 select a.id=b.id or (a.unit_id is not null and a.unit_id=b.unit_id) or (a.property_id is not null and a.property_id=b.property_id and (a.unit_id is null or b.unit_id is null));
$$;
revoke all on function private.listing_resources_overlap(public.listings,public.listings) from public,anon,authenticated;
create function private.guard_managed_resource_schedule() returns trigger language plpgsql security definer set search_path='' as $$
declare resource public.listings;
begin
 if tg_table_name='viewing_slots' then
  if new.state='closed' then return new;end if;
 else
  if new.status<>'scheduled' then return new;end if;
 end if;
 select * into resource from public.listings where id=new.listing_id for share;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(resource.organization_id::text,71));
 if exists(select 1 from public.viewing_slots s join public.listings l on l.id=s.listing_id where s.state<>'closed' and (tg_table_name<>'viewing_slots' or s.id<>new.id) and tstzrange(s.starts_at,s.ends_at,'[)') && tstzrange(new.starts_at,new.ends_at,'[)') and private.listing_resources_overlap(resource,l)) or exists(select 1 from public.open_house_events e join public.listings l on l.id=e.listing_id where e.status='scheduled' and (tg_table_name<>'open_house_events' or e.id<>new.id) and tstzrange(e.starts_at,e.ends_at,'[)') && tstzrange(new.starts_at,new.ends_at,'[)') and private.listing_resources_overlap(resource,l)) then raise exception 'Managed property or unit already scheduled' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.guard_managed_resource_schedule() from public,anon,authenticated;
create trigger guard_managed_viewing_resource before insert or update of listing_id,starts_at,ends_at,state on public.viewing_slots for each row execute function private.guard_managed_resource_schedule();
create trigger guard_managed_open_house_resource before insert or update of listing_id,starts_at,ends_at,status on public.open_house_events for each row execute function private.guard_managed_resource_schedule();
create function private.guard_scheduled_listing_resource() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if row(new.property_id,new.unit_id,new.organization_id) is not distinct from row(old.property_id,old.unit_id,old.organization_id) then return new;end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(old.organization_id::text,71));
 if exists(select 1 from public.viewing_slots where listing_id=old.id and state<>'closed' and ends_at>now()) or exists(select 1 from public.open_house_events where listing_id=old.id and status='scheduled' and ends_at>now()) then raise exception 'Resolve active appointments before changing the managed property or unit' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.guard_scheduled_listing_resource() from public,anon,authenticated;
create trigger guard_scheduled_listing_resource before update of property_id,unit_id,organization_id on public.listings for each row execute function private.guard_scheduled_listing_resource();
