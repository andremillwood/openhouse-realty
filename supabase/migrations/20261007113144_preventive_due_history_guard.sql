-- Future cadence revisions cannot reuse or precede an already issued occurrence.
-- Overdue unissued occurrences remain due; this does not silently skip work.
create function private.guard_preventive_due_history() returns trigger
language plpgsql security definer set search_path='' as $$
declare last_issued date;
begin
 if new.next_due_on is distinct from old.next_due_on then
  select max(due_on) into last_issued from public.preventive_maintenance_occurrences where plan_id=old.id and organization_id=old.organization_id;
  if last_issued is not null and new.next_due_on<=last_issued then
   raise exception 'Next due date must follow the latest issued occurrence' using errcode='P0201';
  end if;
 end if;
 return new;
end $$;
revoke all on function private.guard_preventive_due_history() from public,anon,authenticated,service_role;
create trigger guard_preventive_due_history before update of next_due_on on public.preventive_maintenance_plans for each row execute function private.guard_preventive_due_history();
