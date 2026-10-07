-- Committed preventive decisions are captured separately from email delivery.
create table private.preventive_notification_events(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 plan_id uuid not null references public.preventive_maintenance_plans(id),source_event_id uuid not null unique references public.preventive_maintenance_events(id),
 kind text not null check(kind in('plan_created','plan_revised','work_issued','date_skipped')),
 source_version integer not null check(source_version>0),due_on date not null,work_order_id uuid references public.work_orders(id),
 created_at timestamptz not null default statement_timestamp(),
 check((kind='work_issued')=(work_order_id is not null))
);
create index preventive_notice_org_idx on private.preventive_notification_events(organization_id,created_at,id);
alter table private.preventive_notification_events enable row level security;
revoke all on private.preventive_notification_events from public,anon,authenticated,service_role;
grant select on private.preventive_notification_events to service_role;
create trigger immutable_preventive_notice_events before update or delete on private.preventive_notification_events for each row execute function private.guard_finance_immutable();
create function private.capture_preventive_notification_event() returns trigger language plpgsql security definer set search_path='' as $$
declare plan public.preventive_maintenance_plans;notice_kind text;due date;
begin
 if new.actor_user_id is distinct from auth.uid() or private.verified_work_order_organization() is distinct from new.organization_id then raise exception 'Current management decision required' using errcode='42501';end if;
 select * into plan from public.preventive_maintenance_plans where id=new.plan_id and organization_id=new.organization_id;
 if plan.id is null or plan.version<>new.version or (new.snapshot->'after'->>'id')::uuid is distinct from plan.id or (new.snapshot->'after'->>'version')::integer is distinct from plan.version then raise exception 'Current preventive decision binding required' using errcode='23505';end if;
 notice_kind:=case new.action when 'create' then 'plan_created' when 'revise' then 'plan_revised' when 'issue' then 'work_issued' when 'skip' then 'date_skipped' end;
 due:=case when new.action in('issue','skip') then (new.snapshot->'before'->>'next_due_on')::date else plan.next_due_on end;
 if notice_kind is null or due is null then raise exception 'Approved preventive notice scope required' using errcode='23505';end if;
 if new.action='issue' and not exists(select 1 from public.work_orders w where w.id=new.work_order_id and w.organization_id=plan.organization_id and w.property_id=plan.property_id and w.unit_id is not distinct from plan.unit_id) then raise exception 'Issued preventive work binding required' using errcode='23505';end if;
 insert into private.preventive_notification_events(organization_id,plan_id,source_event_id,kind,source_version,due_on,work_order_id)
 values(plan.organization_id,plan.id,new.id,notice_kind,new.version,due,new.work_order_id);
 return new;
end $$;
revoke all on function private.capture_preventive_notification_event() from public,anon,authenticated,service_role;
create trigger capture_preventive_notice after insert on public.preventive_maintenance_events for each row execute function private.capture_preventive_notification_event();
