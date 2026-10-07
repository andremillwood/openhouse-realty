create function private.guard_finance_dimension_history() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='properties' then
  if new.organization_id is distinct from old.organization_id and exists(select 1 from public.finance_journal_lines where property_id=old.id) then raise exception 'Journal history protects property organization' using errcode='23505';end if;
 else
  if new.property_id is distinct from old.property_id and exists(select 1 from public.finance_journal_lines where unit_id=old.id) then raise exception 'Journal history protects unit property' using errcode='23505';end if;
 end if;
 return new;
end $$;
revoke all on function private.guard_finance_dimension_history() from public,anon,authenticated,service_role;
create trigger guard_finance_property_history before update of organization_id on public.properties for each row execute function private.guard_finance_dimension_history();
create trigger guard_finance_unit_history before update of property_id on public.units for each row execute function private.guard_finance_dimension_history();
