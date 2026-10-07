begin;
insert into auth.users(id,email,email_confirmed_at) values
('44556600-0000-4000-8000-000000000001','owner-admin@example.invalid',now()),
('44556600-0000-4000-8000-000000000002','approved-owner@example.invalid',now()),
('44556600-0000-4000-8000-000000000003','owner-manager@example.invalid',now()),
('44556600-0000-4000-8000-000000000004','other-owner@example.invalid',now()),
('44556600-0000-4000-8000-000000000005','unverified-owner@example.invalid',null),
('44556600-0000-4000-8000-000000000006','foreign-owner-admin@example.invalid',now());
insert into public.organizations(id,name) values('44556600-0000-4000-8000-000000000010','Owner fixture'),('44556600-0000-4000-8000-000000000011','Foreign owner fixture');
insert into public.staff_accounts(user_id,organization_id,role) values
('44556600-0000-4000-8000-000000000001','44556600-0000-4000-8000-000000000010','admin'),
('44556600-0000-4000-8000-000000000003','44556600-0000-4000-8000-000000000010','manager'),
('44556600-0000-4000-8000-000000000006','44556600-0000-4000-8000-000000000011','admin');
insert into public.properties(id,organization_id,name) values
('44556600-0000-4000-8000-000000000020','44556600-0000-4000-8000-000000000010','Approved owner property'),
('44556600-0000-4000-8000-000000000021','44556600-0000-4000-8000-000000000011','Foreign owner property');
insert into public.staff_accounts(user_id,organization_id,role) values('44556600-0000-4000-8000-000000000002','44556600-0000-4000-8000-000000000010','finance');

insert into public.units(id,property_id,unit_label) values('44556600-0000-4000-8000-000000000030','44556600-0000-4000-8000-000000000020','Plan fixture unit');
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
set local role authenticated;
select set_config('openhouse.plan_request',gen_random_uuid()::text,true);
select set_config('openhouse.plan',public.manage_preventive_plan(current_setting('openhouse.plan_request')::uuid,'create',null,0,'44556600-0000-4000-8000-000000000020','44556600-0000-4000-8000-000000000030','Approved inspection','Inspect the approved equipment and record findings.','standard',30,(now() at time zone 'America/Jamaica')::date,'active','Approved preventive scope fixture',true)::text,true);
do $$ declare plan uuid:=(current_setting('openhouse.plan')::jsonb->>'id')::uuid;begin
 if public.manage_preventive_plan(current_setting('openhouse.plan_request')::uuid,'create',null,0,'44556600-0000-4000-8000-000000000020','44556600-0000-4000-8000-000000000030','Approved inspection','Inspect the approved equipment and record findings.','standard',30,(now() at time zone 'America/Jamaica')::date,'active','Approved preventive scope fixture',true)<>current_setting('openhouse.plan')::jsonb then raise exception 'Creation retry changed';end if;
 begin perform public.manage_preventive_plan(gen_random_uuid(),'issue',plan,2,null,null,null,null,null,null,null,null,'Stale due plan fixture',true);raise exception 'Stale plan issued';exception when serialization_failure then null;end;
end $$;
select set_config('openhouse.plan_issue',gen_random_uuid()::text,true);
select set_config('openhouse.plan_work',public.manage_preventive_plan(current_setting('openhouse.plan_issue')::uuid,'issue',(current_setting('openhouse.plan')::jsonb->>'id')::uuid,1,null,null,null,null,null,null,null,null,'Approved due work fixture',true)::text,true);
do $$ declare plan uuid:=(current_setting('openhouse.plan')::jsonb->>'id')::uuid;rewind integer;begin
 if public.manage_preventive_plan(current_setting('openhouse.plan_issue')::uuid,'issue',plan,1,null,null,null,null,null,null,null,null,'Approved due work fixture',true)<>current_setting('openhouse.plan_work')::jsonb then raise exception 'Occurrence retry changed';end if;
 if (select count(*) from public.work_orders)<>1 or (select count(*) from public.preventive_maintenance_occurrences)<>1 then raise exception 'Occurrence duplicated';end if;
 if not exists(select 1 from public.preventive_maintenance_plans where id=plan and version=2 and next_due_on=(now() at time zone 'America/Jamaica')::date+30) then raise exception 'Cadence not advanced';end if;
 if not exists(select 1 from public.work_orders where id=(current_setting('openhouse.plan_work')::jsonb->>'work_order_id')::uuid and status='reported' and revision=1 and unit_id='44556600-0000-4000-8000-000000000030') then raise exception 'Shared work order scope missing';end if;
 begin perform public.manage_preventive_plan(gen_random_uuid(),'issue',plan,2,null,null,null,null,null,null,null,null,'Premature work fixture',true);raise exception 'Future plan issued';exception when unique_violation then null;end;
 for rewind in 0..1 loop
  begin perform public.manage_preventive_plan(gen_random_uuid(),'revise',plan,2,null,null,'Approved inspection','Inspect the approved equipment and record findings.','standard',30,(now() at time zone 'America/Jamaica')::date-rewind,'active','Invalid due date reuse fixture',true);raise exception 'Issued or earlier due date accepted';exception when sqlstate 'P0201' then null;end;
 end loop;
 if not exists(select 1 from public.preventive_maintenance_plans where id=plan and version=2 and next_due_on=(now() at time zone 'America/Jamaica')::date+30) or (select count(*) from public.preventive_maintenance_events where plan_id=plan)<>2 then raise exception 'Rejected revision changed plan history';end if;
 perform public.manage_preventive_plan(gen_random_uuid(),'revise',plan,2,null,null,'Approved inspection','Inspect the approved equipment and record findings.','standard',30,(now() at time zone 'America/Jamaica')::date+30,'paused','Approved plan pause fixture',true);
 begin perform public.manage_preventive_plan(gen_random_uuid(),'issue',plan,3,null,null,null,null,null,null,null,null,'Paused work fixture',true);raise exception 'Paused plan issued';exception when unique_violation then null;end;
 perform public.manage_preventive_plan(gen_random_uuid(),'revise',plan,3,null,null,'Approved inspection','Inspect the approved equipment and record findings.','standard',30,(now() at time zone 'America/Jamaica')::date+30,'retired','Approved plan retirement fixture',true);
 begin perform public.manage_preventive_plan(gen_random_uuid(),'revise',plan,4,null,null,'Approved inspection','Inspect the approved equipment and record findings.','standard',30,(now() at time zone 'America/Jamaica')::date+30,'active','Attempt reactivation fixture',true);raise exception 'Retired plan reopened';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin if exists(select 1 from public.preventive_maintenance_plans) or exists(select 1 from public.preventive_maintenance_occurrences) then raise exception 'Foreign plan disclosure';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ begin
 if exists(select 1 from public.preventive_maintenance_plans) then raise exception 'Finance plan disclosure';end if;
 begin perform public.manage_preventive_plan(gen_random_uuid(),'issue',(current_setting('openhouse.plan')::jsonb->>'id')::uuid,4,null,null,null,null,null,null,null,null,'Unauthorized issue fixture',true);raise exception 'Finance issued plan';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 begin delete from public.preventive_maintenance_plans;raise exception 'Plan history deleted';exception when unique_violation then null;end;
 begin update public.preventive_maintenance_occurrences set due_on=due_on+1;raise exception 'Occurrence history mutable';exception when unique_violation then null;end;
 begin update public.properties set organization_id='44556600-0000-4000-8000-000000000011' where id='44556600-0000-4000-8000-000000000020';raise exception 'Plan property moved';exception when unique_violation then null;end;
 if has_table_privilege('service_role','public.preventive_maintenance_plans','UPDATE') or has_table_privilege('authenticated','public.preventive_maintenance_events','INSERT') then raise exception 'Direct plan writes open';end if;
end $$;
rollback;
