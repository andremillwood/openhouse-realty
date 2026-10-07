-- Approved preparation is a retained snapshot, never a service-editable signature record.
revoke insert,update,delete on public.rental_lease_drafts from service_role;
create function private.guard_lease_draft_immutable() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Lease preparation history cannot be deleted' using errcode='23505';end if;
 if (to_jsonb(new)-array['state','closed_at','closed_reason']) is distinct from (to_jsonb(old)-array['state','closed_at','closed_reason']) then
  raise exception 'Approved lease preparation terms are immutable' using errcode='23505';
 end if;
 if old.state<>'prepared' or new.state not in('superseded','voided') or new.closed_at is null or new.closed_at<old.created_at or new.closed_reason is null or length(trim(new.closed_reason)) not between 5 and 500 then
  raise exception 'Only explained closure of current lease preparation is permitted' using errcode='23505';
 end if;
 return new;
end $$;
revoke all on function private.guard_lease_draft_immutable() from public,anon,authenticated,service_role;
create trigger guard_lease_draft_immutable before update or delete on public.rental_lease_drafts for each row execute function private.guard_lease_draft_immutable();
