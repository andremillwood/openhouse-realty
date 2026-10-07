create function private.guard_prospect_calendar() returns trigger language plpgsql security definer set search_path='' as $$
declare starts timestamptz;ends timestamptz;
begin
 if tg_table_name='viewings' then
  if new.status<>'confirmed' and not(new.status='requested' and new.hold_expires_at>now()) then return new;end if;
  starts:=new.requested_for;ends:=new.ends_at;
 else
  if new.status<>'going' then return new;end if;
  select starts_at,ends_at into starts,ends from public.open_house_events where id=new.event_id and status='scheduled';
  if starts is null then return new;end if;
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text,77));
 if tg_table_name='viewings' then
  if exists(select 1 from public.open_house_rsvps r join public.open_house_events e on e.id=r.event_id where r.user_id=new.user_id and r.status='going' and e.status='scheduled' and tstzrange(e.starts_at,e.ends_at,'[)') && tstzrange(starts,ends,'[)')) then raise exception 'An open house reservation overlaps this viewing' using errcode='23505';end if;
 else
  if exists(select 1 from public.viewings v where v.user_id=new.user_id and (v.status='confirmed' or (v.status='requested' and v.hold_expires_at>now())) and tstzrange(v.requested_for,v.ends_at,'[)') && tstzrange(starts,ends,'[)')) then raise exception 'An active viewing overlaps this open house' using errcode='23505';end if;
 end if;
 return new;
end $$;
revoke all on function private.guard_prospect_calendar() from public,anon,authenticated;
create trigger guard_viewing_prospect_calendar before insert or update of status,requested_for,ends_at,hold_expires_at on public.viewings for each row execute function private.guard_prospect_calendar();
create trigger guard_open_house_prospect_calendar before insert or update of status,party_size on public.open_house_rsvps for each row execute function private.guard_prospect_calendar();
