-- No captured events exist at rollout; sequence gives reliable within-transaction ordering.
alter table private.maintenance_notification_events add column event_sequence bigint generated always as identity unique;
create index maintenance_entry_sequence_idx on private.maintenance_notification_events(offer_id,event_sequence desc) where kind='entry_updated';
create or replace function private.maintenance_notice_current(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(
 select 1 from private.maintenance_notification_events n
 join public.contractor_work_offers o on o.id=n.offer_id and o.organization_id=n.organization_id and o.work_order_id=n.work_order_id
 join public.work_orders w on w.id=n.work_order_id and w.organization_id=n.organization_id
 join public.contractor_accounts c on c.id=o.contractor_id and c.organization_id=n.organization_id and c.user_id=n.contractor_user_id
 join auth.users u on u.id=c.user_id
 where n.id=p_id and n.created_at>now()-interval '7 days' and n.offer_version=o.version and n.work_version=w.revision
 and (n.kind='report_submitted' or (c.is_active and u.email_confirmed_at is not null and u.email is not null))
 and case
 when n.kind='offer_created' then n.source_table='contractor_work_offer_changes' and o.state='offered' and o.expires_at>now() and o.work_version=w.revision and exists(select 1 from public.contractor_work_offer_changes a where a.id=n.source_id and a.offer_id=o.id and a.organization_id=n.organization_id and a.version=n.source_version and a.new_state='offered')
 when n.kind='offer_closed' then n.source_table='contractor_work_offer_changes' and o.state in('declined','withdrawn','expired') and exists(select 1 from public.contractor_work_offer_changes a where a.id=n.source_id and a.offer_id=o.id and a.organization_id=n.organization_id and a.version=n.source_version and a.new_state=o.state) and not exists(select 1 from public.contractor_work_offers replacement where replacement.work_order_id=w.id and replacement.state in('offered','accepted'))
 when n.kind in('visit_proposed','visit_confirmed','visit_cancelled') then n.source_table='contractor_visit_changes' and o.state='accepted' and o.work_version=w.revision and exists(select 1 from public.contractor_visit_changes a join public.contractor_visits v on v.id=a.visit_id where a.id=n.source_id and a.organization_id=n.organization_id and v.offer_id=o.id and v.organization_id=n.organization_id and v.contractor_user_id=n.contractor_user_id and a.version=n.source_version and v.version=n.source_version and
 ((n.kind='visit_proposed' and v.state='proposed' and v.starts_at>now() and w.status='assigned') or
 (n.kind='visit_confirmed' and v.state='confirmed' and v.ends_at>now() and w.status='scheduled') or
 (n.kind='visit_cancelled' and v.state='cancelled' and not exists(select 1 from public.contractor_visits active where active.offer_id=o.id and active.state in('proposed','confirmed')))))
 when n.kind='entry_updated' then not exists(select 1 from private.maintenance_notification_events newer where newer.offer_id=n.offer_id and newer.kind='entry_updated' and newer.event_sequence>n.event_sequence) and n.source_table='contractor_entry_permit_changes' and o.state='accepted' and o.work_version=w.revision and w.status in('scheduled','on_site','in_progress') and exists(select 1 from public.contractor_entry_permit_changes a join public.contractor_entry_permits p on p.id=a.permit_id join public.contractor_visits v on v.id=p.visit_id where a.id=n.source_id and a.organization_id=n.organization_id and p.organization_id=n.organization_id and v.offer_id=o.id and v.state='confirmed' and p.contractor_user_id=n.contractor_user_id and a.version=n.source_version and p.version=n.source_version and p.valid_until>now())
 when n.kind in('report_submitted','changes_requested','work_completed') then n.source_table='contractor_completion_changes' and exists(select 1 from public.contractor_completion_changes a join public.contractor_completion_reports r on r.id=a.report_id where a.id=n.source_id and a.organization_id=n.organization_id and r.offer_id=o.id and r.organization_id=n.organization_id and r.contractor_user_id=n.contractor_user_id and a.version=n.source_version and r.version=n.source_version and
 ((n.kind='report_submitted' and r.state='submitted' and o.state='accepted' and w.status='in_progress') or
 (n.kind='changes_requested' and r.state='changes_requested' and o.state='accepted' and w.status='in_progress') or
 (n.kind='work_completed' and r.state='approved' and o.state='completed' and w.status='completed' and w.completed_at is not null)))
 when n.kind='return_visit' then n.source_table='work_order_changes' and o.state='accepted' and o.work_version=w.revision and w.status='assigned' and exists(select 1 from public.work_order_changes a where a.id=n.source_id and a.work_order_id=w.id and a.organization_id=n.organization_id and a.version=n.source_version and a.action='return_visit')
 else false end
 );
$$;
revoke all on function private.maintenance_notice_current(uuid) from public,anon,authenticated,service_role;
grant execute on function private.maintenance_notice_current(uuid) to service_role;
