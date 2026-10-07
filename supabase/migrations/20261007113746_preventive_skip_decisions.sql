-- A skipped date is an explicit management decision, never completed maintenance.
alter table public.preventive_maintenance_events drop constraint preventive_maintenance_events_action_check;
alter table public.preventive_maintenance_events add constraint preventive_maintenance_events_action_check check(action in('create','revise','issue','skip'));
create table public.preventive_maintenance_skips(
 plan_id uuid not null references public.preventive_maintenance_plans(id),due_on date not null,
 organization_id uuid not null references public.organizations(id),event_id uuid not null unique references public.preventive_maintenance_events(id),
 snapshot jsonb not null,created_at timestamptz not null default statement_timestamp(),primary key(plan_id,due_on)
);
alter table public.preventive_maintenance_skips enable row level security;
revoke all on public.preventive_maintenance_skips from public,anon,authenticated,service_role;
grant select on public.preventive_maintenance_skips to authenticated,service_role;
create policy "management reads own skipped preventive dates" on public.preventive_maintenance_skips for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create trigger immutable_preventive_skips before update or delete on public.preventive_maintenance_skips for each row execute function private.guard_finance_immutable();
create or replace function private.guard_preventive_due_history() returns trigger
language plpgsql security definer set search_path='' as $$
declare last_decided date;
begin
 if new.next_due_on is distinct from old.next_due_on then
  select max(due_on) into last_decided from (
   select due_on from public.preventive_maintenance_occurrences where plan_id=old.id and organization_id=old.organization_id
   union all select due_on from public.preventive_maintenance_skips where plan_id=old.id and organization_id=old.organization_id
  ) dates;
  if last_decided is not null and new.next_due_on<=last_decided then
   raise exception 'Next due date must follow the latest issued or skipped occurrence' using errcode='P0201';
  end if;
 end if;
 return new;
end $$;
create function private.skip_preventive_occurrence(p_request_id uuid,p_plan_id uuid,p_expected_version integer,p_reason text,p_approved boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_work_order_organization();plan public.preventive_maintenance_plans;prior public.preventive_maintenance_events;payload jsonb;before_snapshot jsonb;event_id uuid:=gen_random_uuid();due date;
begin
 if caller is null or org is null then raise exception 'Verified management required' using errcode='42501';end if;
 if p_request_id is null or p_plan_id is null or p_expected_version is null or p_expected_version<1 or p_expected_version>=2147483647 or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Current revision and explicit skip approval required' using errcode='22023';end if;
 payload:=jsonb_build_object('action','skip','plan_id',p_plan_id,'version',p_expected_version,'reason',trim(p_reason));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_work_order_organization() is distinct from org then raise exception 'Management authority changed' using errcode='42501';end if;
 select * into prior from public.preventive_maintenance_events where actor_user_id=caller and request_id=p_request_id;
 if prior.id is not null then
  if prior.organization_id<>org or prior.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
  return jsonb_build_object('id',prior.plan_id,'version',prior.version,'work_order_id',null);
 end if;
 select * into plan from public.preventive_maintenance_plans where id=p_plan_id and organization_id=org for update;
 if plan.id is null then raise exception 'Organization preventive plan required' using errcode='42501';end if;
 if plan.version<>p_expected_version then raise exception 'Preventive plan changed; refresh' using errcode='40001';end if;
 if plan.state<>'active' or plan.next_due_on>(statement_timestamp() at time zone 'America/Jamaica')::date then raise exception 'Active due plan required' using errcode='23505';end if;
 if (select count(*) from public.preventive_maintenance_events where actor_user_id=caller and action='skip' and created_at>statement_timestamp()-interval '1 day')>=100 then raise exception 'Daily skip decision limit reached' using errcode='23505';end if;
 due:=plan.next_due_on;before_snapshot:=to_jsonb(plan);
 if exists(select 1 from public.preventive_maintenance_occurrences where plan_id=plan.id and due_on=due) or exists(select 1 from public.preventive_maintenance_skips where plan_id=plan.id and due_on=due) then raise exception 'Due date already decided' using errcode='23505';end if;
 update public.preventive_maintenance_plans set next_due_on=next_due_on+interval_days,version=version+1,updated_at=statement_timestamp() where id=plan.id returning * into plan;
 insert into public.preventive_maintenance_events(id,plan_id,organization_id,actor_user_id,request_id,action,version,payload,snapshot,reason)
 values(event_id,plan.id,org,caller,p_request_id,'skip',plan.version,payload,jsonb_build_object('before',before_snapshot,'after',to_jsonb(plan)),trim(p_reason));
 insert into public.preventive_maintenance_skips(plan_id,due_on,organization_id,event_id,snapshot) values(plan.id,due,org,event_id,before_snapshot);
 return jsonb_build_object('id',plan.id,'version',plan.version,'work_order_id',null);
end $$;
revoke all on function private.skip_preventive_occurrence(uuid,uuid,integer,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.skip_preventive_occurrence(uuid,uuid,integer,text,boolean) to authenticated;
create function public.skip_preventive_occurrence(p_request_id uuid,p_plan_id uuid,p_expected_version integer,p_reason text,p_approved boolean) returns jsonb
language sql security invoker set search_path='' as $$select private.skip_preventive_occurrence(p_request_id,p_plan_id,p_expected_version,p_reason,p_approved);$$;
revoke all on function public.skip_preventive_occurrence(uuid,uuid,integer,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.skip_preventive_occurrence(uuid,uuid,integer,text,boolean) to authenticated;
