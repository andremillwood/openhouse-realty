begin;
insert into auth.users(id,email,email_confirmed_at) values
('11223300-0000-4000-8000-000000000001','work-manager@example.invalid',now()),
('11223300-0000-4000-8000-000000000002','work-realtor@example.invalid',now()),
('11223300-0000-4000-8000-000000000003','work-foreign@example.invalid',now()),
('11223300-0000-4000-8000-000000000004','work-unverified@example.invalid',null),
('11223300-0000-4000-8000-000000000005','work-prospect@example.invalid',now());
insert into public.organizations(id,name) values('11223300-0000-4000-8000-000000000006','Work order fixtures'),('11223300-0000-4000-8000-000000000007','Foreign work order fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
('11223300-0000-4000-8000-000000000001','11223300-0000-4000-8000-000000000006','manager'),
('11223300-0000-4000-8000-000000000002','11223300-0000-4000-8000-000000000006','realtor'),
('11223300-0000-4000-8000-000000000003','11223300-0000-4000-8000-000000000007','admin'),
('11223300-0000-4000-8000-000000000004','11223300-0000-4000-8000-000000000006','manager');
insert into public.properties(id,organization_id,name) values('11223300-0000-4000-8000-000000000008','11223300-0000-4000-8000-000000000006','Managed fixture'),('11223300-0000-4000-8000-000000000009','11223300-0000-4000-8000-000000000007','Foreign fixture');
insert into public.units(id,property_id,unit_label) values('11223300-0000-4000-8000-000000000010','11223300-0000-4000-8000-000000000008','A'),('11223300-0000-4000-8000-000000000011','11223300-0000-4000-8000-000000000009','Foreign A');

insert into auth.users(id,email,email_confirmed_at,is_anonymous) values('11223300-0000-4000-8000-000000000015','target-anonymous@example.invalid',now(),true);
insert into public.staff_accounts(user_id,organization_id,role) values('11223300-0000-4000-8000-000000000015','11223300-0000-4000-8000-000000000006','manager');
select set_config('request.jwt.claim.sub','11223300-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.target_order',public.manage_work_order(gen_random_uuid(),'create',null,0,'11223300-0000-4000-8000-000000000008',null,'Service target fixture','Detailed service target fixture issue.','standard','Manager reporting context')->>'id',true);
select set_config('request.jwt.claim.sub','11223300-0000-4000-8000-000000000003',true);
select set_config('openhouse.foreign_target_order',public.manage_work_order(gen_random_uuid(),'create',null,0,'11223300-0000-4000-8000-000000000009',null,'Foreign service fixture','Detailed foreign service target fixture.','standard','Manager reporting context')->>'id',true);
select set_config('request.jwt.claim.sub','11223300-0000-4000-8000-000000000001',true);
select set_config('openhouse.target_receipt',public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'response',0,'set','2030-10-09T14:00:00Z','Approved response target',true,'11223300-0000-4000-8000-000000000020')::text,true);
do $$ declare receipt jsonb:=current_setting('openhouse.target_receipt')::jsonb;begin
 if receipt->>'work_order_version'<>'1' or receipt->>'version'<>'1' or receipt->>'kind'<>'response' then raise exception 'Target receipt binding incorrect';end if;
 if public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'response',0,'set','2030-10-09T14:00:00Z','Approved response target',true,'11223300-0000-4000-8000-000000000020')<>receipt then raise exception 'Retry changed receipt';end if;
 if(select count(*) from public.work_order_service_target_events)<>1 then raise exception 'Retry duplicated event';end if;
 if not exists(select 1 from public.work_order_service_target_events where work_order_id=current_setting('openhouse.target_order')::uuid and organization_id='11223300-0000-4000-8000-000000000006' and actor_user_id=auth.uid()) then raise exception 'Trusted identity missing';end if;
 begin perform public.record_work_order_service_target(current_setting('openhouse.foreign_target_order')::uuid,1,'response',0,'set','2030-10-09','Foreign target denied',true,gen_random_uuid());raise exception 'Foreign target accepted';exception when insufficient_privilege then null;end;
 begin perform public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'response',0,'set','2030-10-09','Changed target reason',true,'11223300-0000-4000-8000-000000000020');raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'response',0,'set','2030-10-09','Stale target revision',true,gen_random_uuid());raise exception 'Stale target accepted';exception when serialization_failure then null;end;
 begin perform public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,2,'resolution',0,'set','2030-10-09','Stale work revision',true,gen_random_uuid());raise exception 'Stale work accepted';exception when serialization_failure then null;end;
 begin perform public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'resolution',0,'set','2020-10-09','Past target denied',true,gen_random_uuid());raise exception 'Past target accepted';exception when invalid_parameter_value then null;end;
 begin perform public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'resolution',0,'set',null,'Missing date denied',true,gen_random_uuid());raise exception 'Missing date accepted';exception when invalid_parameter_value then null;end;
 begin perform public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'resolution',0,'clear','2030-10-09','Clear date denied',true,gen_random_uuid());raise exception 'Clear with date accepted';exception when invalid_parameter_value then null;end;
 begin perform public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'resolution',0,'set','2030-10-09','Unapproved target denied',false,gen_random_uuid());raise exception 'Unapproved target accepted';exception when invalid_parameter_value then null;end;
 begin delete from public.work_order_service_target_events;raise exception 'Direct deletion accepted';exception when insufficient_privilege then null;end;
end $$;
select public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'response',1,'clear',null,'Cleared by approved review',true,'11223300-0000-4000-8000-000000000022');
do $$ declare latest jsonb;begin
 select jsonb_agg(s) into latest from public.work_order_service_target_summary(array[current_setting('openhouse.target_order')::uuid,current_setting('openhouse.foreign_target_order')::uuid]) s;
 if jsonb_array_length(latest)<>1 or latest->0->>'version'<>'2' or latest->0->>'action'<>'clear' or latest->0->>'due_at' is not null then raise exception 'Summary lost latest clear or organization scope';end if;
 begin perform public.work_order_service_target_summary(array[]::uuid[]);raise exception 'Empty summary accepted';exception when invalid_parameter_value then null;end;
 begin perform public.work_order_service_target_summary(array_fill(gen_random_uuid(),array[26]));raise exception 'Oversized summary accepted';exception when invalid_parameter_value then null;end;
 begin perform public.work_order_service_target_summary(array[null]::uuid[]);raise exception 'Null summary accepted';exception when invalid_parameter_value then null;end;
end $$;
select public.manage_work_order(gen_random_uuid(),'cancel',current_setting('openhouse.target_order')::uuid,1,null,null,null,null,null,'Fixture work order cancelled');
do $$ begin
 if public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'response',0,'set','2030-10-09T14:00:00Z','Approved response target',true,'11223300-0000-4000-8000-000000000020')<>current_setting('openhouse.target_receipt')::jsonb then raise exception 'Closed replay lost original receipt';end if;
 begin perform public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,2,'response',2,'set','2030-10-09','Closed target denied',true,gen_random_uuid());raise exception 'Closed work target accepted';exception when serialization_failure then null;end;
end $$;
reset role;
do $$ begin begin update public.work_order_service_target_events set reason='Mutated reason';raise exception 'History mutation accepted';exception when unique_violation then null;end;end $$;
set local role authenticated;
do $$ declare caller uuid;begin
 foreach caller in array array['11223300-0000-4000-8000-000000000002'::uuid,'11223300-0000-4000-8000-000000000003'::uuid,'11223300-0000-4000-8000-000000000004'::uuid,'11223300-0000-4000-8000-000000000005'::uuid,'11223300-0000-4000-8000-000000000015'::uuid] loop
 perform set_config('request.jwt.claim.sub',caller::text,true);
 if exists(select 1 from public.work_order_service_target_summary(array[current_setting('openhouse.target_order')::uuid])) then raise exception 'Unauthorized summary visible';end if;
 if exists(select 1 from public.work_order_service_target_events where organization_id='11223300-0000-4000-8000-000000000006') then raise exception 'Unauthorized target visible';end if;
 begin perform public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,2,'response',2,'clear',null,'Unauthorized clear denied',true,gen_random_uuid());raise exception 'Unauthorized target accepted';exception when insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
update public.staff_accounts set role='realtor' where user_id='11223300-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','11223300-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.work_order_service_target_events) then raise exception 'Revoked targets visible';end if;
 begin perform public.record_work_order_service_target(current_setting('openhouse.target_order')::uuid,1,'response',0,'set','2030-10-09T14:00:00Z','Approved response target',true,'11223300-0000-4000-8000-000000000020');raise exception 'Revoked replay accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role service_role;
do $$ begin begin delete from public.work_order_service_target_events;raise exception 'Service direct write accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
set local role anon;
do $$ begin begin perform 1 from public.work_order_service_target_events;raise exception 'Anon history visible';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
