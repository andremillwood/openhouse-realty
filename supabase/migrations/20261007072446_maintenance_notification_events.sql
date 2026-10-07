-- Private committed event snapshots. Delivery remains separate from business mutations.
create table private.maintenance_notification_events(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),offer_id uuid not null references public.contractor_work_offers(id),work_order_id uuid not null references public.work_orders(id),contractor_user_id uuid not null references auth.users(id),
 kind text not null check(kind in('offer_created','offer_closed','visit_proposed','visit_confirmed','visit_cancelled','entry_updated','report_submitted','changes_requested','work_completed','return_visit')),
 source_table text not null check(source_table in('contractor_work_offer_changes','contractor_visit_changes','contractor_entry_permit_changes','contractor_completion_changes','work_order_changes')),source_id uuid not null,source_version integer not null check(source_version>0),offer_version integer not null check(offer_version>0),work_version integer not null check(work_version>0),created_at timestamptz not null default now(),unique(source_table,source_id)
);
create index maintenance_notification_org_idx on private.maintenance_notification_events(organization_id,created_at,id);
create index maintenance_notification_offer_idx on private.maintenance_notification_events(offer_id,created_at,id);
alter table private.maintenance_notification_events enable row level security;
revoke all on private.maintenance_notification_events from public,anon,authenticated,service_role;
grant select on private.maintenance_notification_events to service_role;
create function private.capture_maintenance_notification_event() returns trigger language plpgsql security definer set search_path='' as $$
declare offer public.contractor_work_offers;job public.work_orders;target_offer uuid;kind text;contractor_user uuid;
begin
 if tg_table_name='contractor_work_offer_changes' then
 target_offer:=new.offer_id;kind:=case when new.new_state='offered' then 'offer_created' when new.new_state in('withdrawn','expired','declined') then 'offer_closed' else null end;
 elsif tg_table_name='contractor_visit_changes' then
 select offer_id into target_offer from public.contractor_visits where id=new.visit_id;
 kind:=case new.action when 'propose' then 'visit_proposed' when 'confirm' then 'visit_confirmed' when 'cancel' then 'visit_cancelled' else null end;
 elsif tg_table_name='contractor_entry_permit_changes' then
 select v.offer_id into target_offer from public.contractor_entry_permits p join public.contractor_visits v on v.id=p.visit_id where p.id=new.permit_id;kind:='entry_updated';
 elsif tg_table_name='contractor_completion_changes' then
 select offer_id into target_offer from public.contractor_completion_reports where id=new.report_id;
 kind:=case new.action when 'submit' then 'report_submitted' when 'request_changes' then 'changes_requested' when 'approve' then 'work_completed' else null end;
 elsif tg_table_name='work_order_changes' and new.action='return_visit' then
 select offer_id into target_offer from public.contractor_completion_reports where id=(new.payload->>'report_id')::uuid;kind:='return_visit';
 end if;
 if kind is null then return new;end if;
 select * into offer from public.contractor_work_offers where id=target_offer and organization_id=new.organization_id;
 select * into job from public.work_orders where id=offer.work_order_id and organization_id=new.organization_id;
 select user_id into contractor_user from public.contractor_accounts where id=offer.contractor_id and organization_id=new.organization_id;
 if offer.id is null or job.id is null or contractor_user is null then raise exception 'Maintenance event binding required' using errcode='23505';end if;
 insert into private.maintenance_notification_events(organization_id,offer_id,work_order_id,contractor_user_id,kind,source_table,source_id,source_version,offer_version,work_version) values(new.organization_id,offer.id,job.id,contractor_user,kind,tg_table_name,new.id,new.version,offer.version,job.revision) on conflict(source_table,source_id) do nothing;
 return new;
end $$;
revoke all on function private.capture_maintenance_notification_event() from public,anon,authenticated,service_role;
create trigger capture_maintenance_notice after insert on public.contractor_work_offer_changes for each row execute function private.capture_maintenance_notification_event();
create trigger capture_maintenance_notice after insert on public.contractor_visit_changes for each row execute function private.capture_maintenance_notification_event();
create trigger capture_maintenance_notice after insert on public.contractor_entry_permit_changes for each row execute function private.capture_maintenance_notification_event();
create trigger capture_maintenance_notice after insert on public.contractor_completion_changes for each row execute function private.capture_maintenance_notification_event();
create trigger capture_maintenance_notice after insert on public.work_order_changes for each row execute function private.capture_maintenance_notification_event();
