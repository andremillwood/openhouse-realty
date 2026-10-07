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
select set_config('openhouse.skip_plan',public.manage_preventive_plan(gen_random_uuid(),'create',null,0,'44556600-0000-4000-8000-000000000020',null,'Approved inspection','Inspect the approved equipment and record findings.','standard',30,(now() at time zone 'America/Jamaica')::date-60,'active','Approved backlog fixture scope',true)::text,true);
select set_config('openhouse.skip_request',gen_random_uuid()::text,true);
select set_config('openhouse.skip_result',public.skip_preventive_occurrence(current_setting('openhouse.skip_request')::uuid,(current_setting('openhouse.skip_plan')::jsonb->>'id')::uuid,1,'Approved missed-date exception fixture',true)::text,true);
do $$ declare plan uuid:=(current_setting('openhouse.skip_plan')::jsonb->>'id')::uuid;begin
 if public.skip_preventive_occurrence(current_setting('openhouse.skip_request')::uuid,plan,1,'Approved missed-date exception fixture',true)<>current_setting('openhouse.skip_result')::jsonb then raise exception 'Skip retry changed';end if;
 if (select count(*) from public.work_orders)<>0 or (select count(*) from public.preventive_maintenance_occurrences)<>0 or (select count(*) from public.preventive_maintenance_skips)<>1 then raise exception 'Skip created work or duplicate decision';end if;
 if not exists(select 1 from public.preventive_maintenance_plans where id=plan and version=2 and next_due_on=(now() at time zone 'America/Jamaica')::date-30) then raise exception 'Skip did not advance exactly one scheduled interval';end if;
 if not exists(select 1 from public.preventive_maintenance_skips s join public.preventive_maintenance_events e on e.id=s.event_id where s.plan_id=plan and s.due_on=(now() at time zone 'America/Jamaica')::date-60 and s.snapshot->>'version'='1' and e.action='skip' and e.work_order_id is null and e.reason='Approved missed-date exception fixture') then raise exception 'Frozen skip scope or approved reason missing';end if;
 begin perform public.skip_preventive_occurrence(current_setting('openhouse.skip_request')::uuid,plan,1,'Changed retry exception fixture',true);raise exception 'Changed skip retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.manage_preventive_plan(current_setting('openhouse.skip_request')::uuid,'issue',plan,1,null,null,null,null,null,null,null,null,'Approved missed-date exception fixture',true);raise exception 'Skip request reused by issue';exception when invalid_parameter_value then null;end;
 begin perform public.skip_preventive_occurrence(gen_random_uuid(),plan,1,'Stale skip fixture decision',true);raise exception 'Stale skip accepted';exception when serialization_failure then null;end;
 begin perform public.skip_preventive_occurrence(gen_random_uuid(),plan,2,'Unchecked skip fixture decision',false);raise exception 'Unapproved skip accepted';exception when invalid_parameter_value then null;end;
 begin perform public.manage_preventive_plan(gen_random_uuid(),'revise',plan,2,null,null,'Approved inspection','Inspect the approved equipment and record findings.','standard',30,(now() at time zone 'America/Jamaica')::date-60,'active','Attempt skipped due-date rewind',true);raise exception 'Skipped date reused';exception when sqlstate 'P0201' then null;end;
 perform public.manage_preventive_plan(gen_random_uuid(),'issue',plan,2,null,null,null,null,null,null,null,null,'Approved next overdue work fixture',true);
 perform public.skip_preventive_occurrence(gen_random_uuid(),plan,3,'Approved second skipped-date exception',true);
 begin perform public.skip_preventive_occurrence(gen_random_uuid(),plan,4,'Premature skip fixture decision',true);raise exception 'Future skip accepted';exception when unique_violation then null;end;
 if (select count(*) from public.work_orders)<>1 or (select count(*) from public.preventive_maintenance_occurrences)<>1 or (select count(*) from public.preventive_maintenance_skips)<>2 then raise exception 'Issued and skipped dates not distinct';end if;
 if exists(select 1 from public.preventive_maintenance_skips s join public.preventive_maintenance_occurrences o using(plan_id,due_on)) then raise exception 'One date issued and skipped';end if;
 perform public.manage_preventive_plan(gen_random_uuid(),'revise',plan,4,null,null,'Approved inspection','Inspect the approved equipment and record findings.','standard',30,(now() at time zone 'America/Jamaica')::date+1,'paused','Approved pause fixture decision',true);
 begin perform public.skip_preventive_occurrence(gen_random_uuid(),plan,5,'Paused skip fixture decision',true);raise exception 'Paused skip accepted';exception when unique_violation then null;end;
 perform public.manage_preventive_plan(gen_random_uuid(),'revise',plan,5,null,null,'Approved inspection','Inspect the approved equipment and record findings.','standard',30,(now() at time zone 'America/Jamaica')::date+1,'retired','Approved retire fixture decision',true);
 begin perform public.skip_preventive_occurrence(gen_random_uuid(),plan,6,'Retired skip fixture decision',true);raise exception 'Retired skip accepted';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin if exists(select 1 from public.preventive_maintenance_skips) then raise exception 'Foreign skip disclosure';end if;
 begin perform public.skip_preventive_occurrence(gen_random_uuid(),(current_setting('openhouse.skip_plan')::jsonb->>'id')::uuid,6,'Foreign skip fixture decision',true);raise exception 'Foreign skip accepted';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.preventive_maintenance_skips) then raise exception 'Finance skip disclosure';end if;
 begin perform public.skip_preventive_occurrence(gen_random_uuid(),(current_setting('openhouse.skip_plan')::jsonb->>'id')::uuid,6,'Finance skip fixture decision',true);raise exception 'Finance skip accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$ begin
 begin update public.preventive_maintenance_skips set due_on=due_on+1;raise exception 'Skip history mutable';exception when unique_violation then null;end;
 if has_table_privilege('service_role','public.preventive_maintenance_skips','INSERT') or has_table_privilege('authenticated','public.preventive_maintenance_skips','DELETE') or has_function_privilege('service_role','public.skip_preventive_occurrence(uuid,uuid,integer,text,boolean)','EXECUTE') then raise exception 'Direct skip writes or service authority open';end if;
end $$;
do $$ begin
 if (select count(*) from private.preventive_notification_events)<>(select count(*) from public.preventive_maintenance_events) then raise exception 'Committed decision capture missing or duplicated';end if;
 if (select count(*) from private.preventive_notification_events where kind='date_skipped')<>2 or (select count(*) from private.preventive_notification_events where kind='work_issued')<>1 then raise exception 'Preventive notice kinds incorrect';end if;
 if exists(select 1 from private.preventive_notification_events n join public.preventive_maintenance_events e on e.id=n.source_event_id where n.organization_id<>e.organization_id or n.plan_id<>e.plan_id or n.source_version<>e.version or n.due_on<>case when e.action in('issue','skip') then (e.snapshot->'before'->>'next_due_on')::date else (e.snapshot->'after'->>'next_due_on')::date end) then raise exception 'Preventive notice snapshot binding incorrect';end if;
 begin update private.preventive_notification_events set due_on=due_on+1;raise exception 'Notice evidence mutable';exception when unique_violation then null;end;
 if has_table_privilege('authenticated','private.preventive_notification_events','SELECT') or has_table_privilege('service_role','private.preventive_notification_events','INSERT') then raise exception 'Private notice evidence authority open';end if;
end $$;
do $$ begin
 if (select count(*) from private.preventive_notification_events where private.preventive_notice_current(id))<>2 then raise exception 'Latest revision and open issued-work eligibility incorrect';end if;
 if exists(select 1 from private.preventive_notification_events where kind in('plan_created','date_skipped') and private.preventive_notice_current(id)) then raise exception 'Superseded plan decision eligible';end if;
 if private.preventive_notice_current(gen_random_uuid()) then raise exception 'Unknown notice eligible';end if;
 if has_function_privilege('authenticated','private.preventive_notice_current(uuid)','EXECUTE') then raise exception 'Client service eligibility access open';end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
set local role authenticated;
select public.manage_work_order(gen_random_uuid(),'cancel',(select work_order_id from public.preventive_maintenance_occurrences limit 1),1,null,null,null,null,null,'Approved notice cancellation fixture');
reset role;
do $$ begin
 if exists(select 1 from private.preventive_notification_events where kind='work_issued' and private.preventive_notice_current(id)) then raise exception 'Cancelled issued work eligible';end if;
end $$;
update auth.users set email_confirmed_at=null where id='44556600-0000-4000-8000-000000000003';
do $$ begin if exists(select 1 from private.preventive_notification_events where private.preventive_notice_current(id)) then raise exception 'Unverified approval actor eligible';end if;end $$;
update auth.users set email_confirmed_at=now() where id='44556600-0000-4000-8000-000000000003';
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
set local role authenticated;
select public.manage_staff_membership(gen_random_uuid(),'owner-manager@example.invalid','finance',(select membership_revision from public.staff_accounts where user_id='44556600-0000-4000-8000-000000000003'),'Approved notice actor demotion fixture',true);
reset role;
do $$ begin if exists(select 1 from private.preventive_notification_events where private.preventive_notice_current(id)) then raise exception 'Demoted approval actor eligible';end if;end $$;
rollback;
