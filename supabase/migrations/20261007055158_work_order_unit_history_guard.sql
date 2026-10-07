create or replace function private.guard_work_order_resource() returns trigger language plpgsql security definer set search_path='' as $$
declare org uuid;
begin
 if tg_op='UPDATE' and row(new.organization_id,new.property_id,new.unit_id,new.reported_by) is distinct from row(old.organization_id,old.property_id,old.unit_id,old.reported_by) then raise exception 'Work order resource and reporter are immutable' using errcode='23505';end if;
 select organization_id into org from public.properties where id=new.property_id for share;
 if org is null or org is distinct from new.organization_id then raise exception 'Organization property required' using errcode='23505';end if;
 if new.unit_id is not null then
 perform 1 from public.units where id=new.unit_id and property_id=new.property_id for share;
 if not found then raise exception 'Property unit required' using errcode='23505';end if;
 end if;
 return new;
end $$;
create function private.guard_work_order_unit_parent() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.property_id is distinct from old.property_id and exists(select 1 from public.work_orders where unit_id=old.id) then raise exception 'Work order history protects unit property' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_work_order_unit_parent() from public,anon,authenticated;
create trigger guard_work_order_unit_parent before update of property_id on public.units for each row execute function private.guard_work_order_unit_parent();
