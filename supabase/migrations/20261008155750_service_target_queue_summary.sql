-- At most 25 visible work orders and 50 current target records per queue request.
create function public.work_order_service_target_summary(p_work_order_ids uuid[])
returns table(work_order_id uuid,kind text,version integer,action text,due_at timestamptz)
language plpgsql stable security invoker set search_path='' as $$
begin
 if p_work_order_ids is null or cardinality(p_work_order_ids) not between 1 and 25 or array_position(p_work_order_ids,null) is not null then
  raise exception 'One to twenty-five work order IDs required' using errcode='22023';
 end if;
 return query select distinct on(e.work_order_id,e.kind) e.work_order_id,e.kind,e.version,e.action,e.due_at
 from public.work_order_service_target_events e where e.work_order_id=any(p_work_order_ids)
 order by e.work_order_id,e.kind,e.version desc;
end $$;
revoke all on function public.work_order_service_target_summary(uuid[]) from public,anon,authenticated,service_role;
grant execute on function public.work_order_service_target_summary(uuid[]) to authenticated;
