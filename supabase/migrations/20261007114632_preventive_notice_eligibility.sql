-- Current-event eligibility is rechecked before queueing and before each send.
create function private.preventive_notice_current(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from private.preventive_notification_events n
  join public.preventive_maintenance_events e on e.id=n.source_event_id and e.plan_id=n.plan_id and e.organization_id=n.organization_id and e.version=n.source_version
  join public.preventive_maintenance_plans p on p.id=n.plan_id and p.organization_id=n.organization_id
  join public.staff_accounts s on s.user_id=e.actor_user_id and s.organization_id=n.organization_id and s.role in('admin','manager')
  join auth.users u on u.id=s.user_id and u.email_confirmed_at is not null
  where n.id=p_id and n.created_at>statement_timestamp()-interval '7 days'
  and n.kind=case e.action when 'create' then 'plan_created' when 'revise' then 'plan_revised' when 'issue' then 'work_issued' when 'skip' then 'date_skipped' end
  and case when n.kind='work_issued' then
   exists(select 1 from public.preventive_maintenance_occurrences o join public.work_orders w on w.id=o.work_order_id
    where o.event_id=e.id and o.plan_id=p.id and o.organization_id=n.organization_id and o.due_on=n.due_on and o.work_order_id=n.work_order_id
    and w.organization_id=n.organization_id and w.property_id=p.property_id and w.unit_id is not distinct from p.unit_id and w.status in('reported','triaged'))
  else p.version=n.source_version and n.work_order_id is null
   and (n.kind<>'date_skipped' or exists(select 1 from public.preventive_maintenance_skips k where k.event_id=e.id and k.plan_id=p.id and k.organization_id=n.organization_id and k.due_on=n.due_on))
  end
 );
$$;
revoke all on function private.preventive_notice_current(uuid) from public,anon,authenticated,service_role;
grant execute on function private.preventive_notice_current(uuid) to service_role;
