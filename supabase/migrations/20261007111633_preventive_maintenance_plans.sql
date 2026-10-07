-- Management chooses cadence explicitly; generating an occurrence does not assign or complete work.
create table public.preventive_maintenance_plans(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),property_id uuid not null references public.properties(id),unit_id uuid references public.units(id),
 title text not null check(length(trim(title)) between 3 and 160),description text not null check(length(trim(description)) between 20 and 5000),priority text not null check(priority in('low','standard','high','urgent')),
 interval_days integer not null check(interval_days between 1 and 366),next_due_on date not null,state text not null check(state in('active','paused','retired')),version integer not null check(version>0),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp(),updated_at timestamptz not null default statement_timestamp()
);
create index preventive_plan_queue_idx on public.preventive_maintenance_plans(organization_id,state,next_due_on,id);
alter table public.preventive_maintenance_plans enable row level security;
revoke all on public.preventive_maintenance_plans from public,anon,authenticated,service_role;
grant select on public.preventive_maintenance_plans to authenticated,service_role;
create policy "management reads own preventive plans" on public.preventive_maintenance_plans for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create table public.preventive_maintenance_events(
 id uuid primary key default gen_random_uuid(),plan_id uuid not null references public.preventive_maintenance_plans(id),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,
 action text not null check(action in('create','revise','issue')),version integer not null,payload jsonb not null,snapshot jsonb not null,reason text not null check(length(trim(reason)) between 5 and 500),work_order_id uuid references public.work_orders(id),created_at timestamptz not null default statement_timestamp(),unique(actor_user_id,request_id)
);
alter table public.preventive_maintenance_events enable row level security;
revoke all on public.preventive_maintenance_events from public,anon,authenticated,service_role;
grant select on public.preventive_maintenance_events to authenticated,service_role;
create index preventive_event_history_idx on public.preventive_maintenance_events(organization_id,plan_id,created_at desc,id);
create policy "management reads own preventive audit" on public.preventive_maintenance_events for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create trigger immutable_preventive_events before update or delete on public.preventive_maintenance_events for each row execute function private.guard_finance_immutable();
create table public.preventive_maintenance_occurrences(
 plan_id uuid not null references public.preventive_maintenance_plans(id),due_on date not null,organization_id uuid not null references public.organizations(id),work_order_id uuid not null unique references public.work_orders(id),event_id uuid not null unique references public.preventive_maintenance_events(id),snapshot jsonb not null,created_at timestamptz not null default statement_timestamp(),primary key(plan_id,due_on)
);
alter table public.preventive_maintenance_occurrences enable row level security;
revoke all on public.preventive_maintenance_occurrences from public,anon,authenticated,service_role;
grant select on public.preventive_maintenance_occurrences to authenticated,service_role;
create policy "management reads own preventive occurrences" on public.preventive_maintenance_occurrences for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create trigger immutable_preventive_occurrences before update or delete on public.preventive_maintenance_occurrences for each row execute function private.guard_finance_immutable();
create function private.guard_preventive_plan() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Preventive history is retained' using errcode='23505';end if;
 if tg_op='UPDATE' then
  if row(new.id,new.organization_id,new.property_id,new.unit_id,new.created_by,new.created_at) is distinct from row(old.id,old.organization_id,old.property_id,old.unit_id,old.created_by,old.created_at) or old.state='retired' or new.version<>old.version+1 then raise exception 'Immutable plan binding and current revision required' using errcode='23505';end if;
 end if;
 perform 1 from public.properties where id=new.property_id and organization_id=new.organization_id for share;
 if not found then raise exception 'Organization property required' using errcode='42501';end if;
 if new.unit_id is not null then perform 1 from public.units where id=new.unit_id and property_id=new.property_id for share;if not found then raise exception 'Property unit required' using errcode='42501';end if;end if;
 return new;
end $$;
revoke all on function private.guard_preventive_plan() from public,anon,authenticated,service_role;
create trigger guard_preventive_plan before insert or update or delete on public.preventive_maintenance_plans for each row execute function private.guard_preventive_plan();
create function private.guard_preventive_property() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.organization_id is distinct from old.organization_id and exists(select 1 from public.preventive_maintenance_plans where property_id=old.id) then raise exception 'Preventive plan history protects property organization' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_preventive_property() from public,anon,authenticated,service_role;
create trigger guard_preventive_property before update of organization_id on public.properties for each row execute function private.guard_preventive_property();
create function private.guard_preventive_unit() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.property_id is distinct from old.property_id and exists(select 1 from public.preventive_maintenance_plans where unit_id=old.id) then raise exception 'Preventive plan history protects unit property' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_preventive_unit() from public,anon,authenticated,service_role;
create trigger guard_preventive_unit before update of property_id on public.units for each row execute function private.guard_preventive_unit();
create function private.manage_preventive_plan(p_request_id uuid,p_action text,p_plan_id uuid,p_expected_version integer,p_property_id uuid,p_unit_id uuid,p_title text,p_description text,p_priority text,p_interval_days integer,p_next_due_on date,p_state text,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_work_order_organization();plan public.preventive_maintenance_plans;prior public.preventive_maintenance_events;payload jsonb;before_snapshot jsonb;result_work uuid;event_id uuid:=gen_random_uuid();due date;
begin
 if caller is null or org is null then raise exception 'Verified management required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('create','revise','issue') or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Current revision and explicit plan approval required' using errcode='22023';end if;
 payload:=jsonb_build_object('action',p_action,'plan_id',p_plan_id,'version',p_expected_version,'property_id',p_property_id,'unit_id',p_unit_id,'title',trim(p_title),'description',trim(p_description),'priority',p_priority,'interval_days',p_interval_days,'next_due_on',p_next_due_on,'state',p_state,'reason',trim(p_reason));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_work_order_organization() is distinct from org then raise exception 'Management authority changed' using errcode='42501';end if;
 select * into prior from public.preventive_maintenance_events where actor_user_id=caller and request_id=p_request_id;
 if prior.id is not null then
  if prior.organization_id<>org or prior.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
  return jsonb_build_object('id',prior.plan_id,'version',prior.version,'work_order_id',prior.work_order_id);
 end if;
 if p_action in('create','revise') then
  if p_title is null or length(trim(p_title)) not between 3 and 160 or p_description is null or length(trim(p_description)) not between 20 and 5000 or p_priority is null or p_priority not in('low','standard','high','urgent') or p_interval_days is null or p_interval_days not between 1 and 366 or p_next_due_on is null or p_next_due_on not between date '2000-01-01' and date '2200-01-01' or p_state is null or p_state not in('active','paused','retired') then raise exception 'Valid approved preventive scope and cadence required' using errcode='22023';end if;
 end if;
 if p_action='create' then
  if p_plan_id is not null or p_expected_version<>0 or p_property_id is null or p_state='retired' then raise exception 'New organization plan required' using errcode='22023';end if;
  if (select count(*) from public.preventive_maintenance_events where actor_user_id=caller and action='create' and created_at>statement_timestamp()-interval '1 day')>=50 then raise exception 'Daily plan limit reached' using errcode='23505';end if;
  insert into public.preventive_maintenance_plans(organization_id,property_id,unit_id,title,description,priority,interval_days,next_due_on,state,version,created_by) values(org,p_property_id,p_unit_id,trim(p_title),trim(p_description),p_priority,p_interval_days,p_next_due_on,p_state,1,caller) returning * into plan;
  before_snapshot:='null'::jsonb;
 else
  if p_plan_id is null or p_expected_version<1 or p_property_id is not null or p_unit_id is not null then raise exception 'Current plan transition required' using errcode='22023';end if;
  select * into plan from public.preventive_maintenance_plans where id=p_plan_id and organization_id=org for update;
  if plan.id is null then raise exception 'Organization preventive plan required' using errcode='42501';end if;
  if plan.version<>p_expected_version then raise exception 'Preventive plan changed; refresh' using errcode='40001';end if;
  if plan.state='retired' then raise exception 'Retired plan is retained' using errcode='23505';end if;
  before_snapshot:=to_jsonb(plan);
  if p_action='revise' then
   update public.preventive_maintenance_plans set title=trim(p_title),description=trim(p_description),priority=p_priority,interval_days=p_interval_days,next_due_on=p_next_due_on,state=p_state,version=version+1,updated_at=statement_timestamp() where id=plan.id returning * into plan;
  else
   if p_title is not null or p_description is not null or p_priority is not null or p_interval_days is not null or p_next_due_on is not null or p_state is not null then raise exception 'Issue current approved scope only' using errcode='22023';end if;
   if plan.state<>'active' or plan.next_due_on>(statement_timestamp() at time zone 'America/Jamaica')::date then raise exception 'Active due plan required' using errcode='23505';end if;
   due:=plan.next_due_on;
   result_work:=(private.manage_work_order(gen_random_uuid(),'create',null,0,plan.property_id,plan.unit_id,plan.title,plan.description,plan.priority,trim(p_reason))->>'id')::uuid;
   update public.preventive_maintenance_plans set next_due_on=next_due_on+interval_days,version=version+1,updated_at=statement_timestamp() where id=plan.id returning * into plan;
  end if;
 end if;
 insert into public.preventive_maintenance_events(id,plan_id,organization_id,actor_user_id,request_id,action,version,payload,snapshot,reason,work_order_id) values(event_id,plan.id,org,caller,p_request_id,p_action,plan.version,payload,jsonb_build_object('before',before_snapshot,'after',to_jsonb(plan)),trim(p_reason),result_work);
 if result_work is not null then insert into public.preventive_maintenance_occurrences(plan_id,due_on,organization_id,work_order_id,event_id,snapshot) values(plan.id,due,org,result_work,event_id,before_snapshot);end if;
 return jsonb_build_object('id',plan.id,'version',plan.version,'work_order_id',result_work);
end $$;
revoke all on function private.manage_preventive_plan(uuid,text,uuid,integer,uuid,uuid,text,text,text,integer,date,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.manage_preventive_plan(uuid,text,uuid,integer,uuid,uuid,text,text,text,integer,date,text,text,boolean) to authenticated;
create function public.manage_preventive_plan(p_request_id uuid,p_action text,p_plan_id uuid,p_expected_version integer,p_property_id uuid,p_unit_id uuid,p_title text,p_description text,p_priority text,p_interval_days integer,p_next_due_on date,p_state text,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.manage_preventive_plan(p_request_id,p_action,p_plan_id,p_expected_version,p_property_id,p_unit_id,p_title,p_description,p_priority,p_interval_days,p_next_due_on,p_state,p_reason,p_approved);$$;
revoke all on function public.manage_preventive_plan(uuid,text,uuid,integer,uuid,uuid,text,text,text,integer,date,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.manage_preventive_plan(uuid,text,uuid,integer,uuid,uuid,text,text,text,integer,date,text,text,boolean) to authenticated;
