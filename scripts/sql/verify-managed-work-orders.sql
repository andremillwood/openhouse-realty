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
select set_config('request.jwt.claim.sub','11223300-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 begin perform public.manage_work_order(gen_random_uuid(),'create',null,0,'11223300-0000-4000-8000-000000000009',null,'Fixture issue','A detailed description of the issue.','standard','Manager reporting context');raise exception 'Foreign property accepted';exception when insufficient_privilege then null;end;
 begin perform public.manage_work_order(gen_random_uuid(),'create',null,0,'11223300-0000-4000-8000-000000000008','11223300-0000-4000-8000-000000000011','Fixture issue','A detailed description of the issue.','standard','Manager reporting context');raise exception 'Foreign unit accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('openhouse.work_order',public.manage_work_order('11223300-0000-4000-8000-000000000012','create',null,0,'11223300-0000-4000-8000-000000000008','11223300-0000-4000-8000-000000000010','Fixture issue','A detailed description of the issue.','standard','Manager reporting context')->>'id',true);
do $$ begin
 if not exists(select 1 from public.work_orders where id=current_setting('openhouse.work_order')::uuid and organization_id='11223300-0000-4000-8000-000000000006' and reported_by=auth.uid() and revision=1 and status='reported') then raise exception 'Work order authority incorrect';end if;
 if public.manage_work_order('11223300-0000-4000-8000-000000000012','create',null,0,'11223300-0000-4000-8000-000000000008','11223300-0000-4000-8000-000000000010','Fixture issue','A detailed description of the issue.','standard','Manager reporting context')->>'id'<>current_setting('openhouse.work_order') then raise exception 'Retry duplicated order';end if;
 if(select count(*) from public.work_order_changes)<>1 then raise exception 'Retry duplicated audit';end if;
 begin perform public.manage_work_order('11223300-0000-4000-8000-000000000012','create',null,0,'11223300-0000-4000-8000-000000000008','11223300-0000-4000-8000-000000000010','Fixture issue','A detailed description of the issue.','high','Manager reporting context');raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin update public.work_orders set status='completed' where id=current_setting('openhouse.work_order')::uuid;raise exception 'Direct transition accepted';exception when insufficient_privilege then null;end;
 begin delete from public.work_order_changes;raise exception 'Audit deletion accepted';exception when insufficient_privilege then null;end;
 begin perform public.manage_work_order(gen_random_uuid(),'triage',current_setting('openhouse.work_order')::uuid,0,null,null,null,null,'high','Triage reason recorded');raise exception 'Stale triage accepted';exception when serialization_failure then null;end;
end $$;
select public.manage_work_order(gen_random_uuid(),'triage',current_setting('openhouse.work_order')::uuid,1,null,null,null,null,'high','Triage reason recorded');
select public.manage_work_order('11223300-0000-4000-8000-000000000013','cancel',current_setting('openhouse.work_order')::uuid,2,null,null,null,null,null,'Issue resolved outside this ticket');
do $$ begin
 if public.manage_work_order('11223300-0000-4000-8000-000000000013','cancel',current_setting('openhouse.work_order')::uuid,2,null,null,null,null,null,'Issue resolved outside this ticket')->>'version'<>'3' then raise exception 'Cancellation retry failed';end if;
 if not exists(select 1 from public.work_order_changes where action='triage' and previous_status='reported' and new_status='triaged' and previous_priority='standard' and new_priority='high') then raise exception 'Triage audit missing';end if;
 begin perform public.manage_work_order(gen_random_uuid(),'triage',current_setting('openhouse.work_order')::uuid,3,null,null,null,null,'urgent','Attempt to reopen ticket');raise exception 'Cancelled ticket reopened';exception when unique_violation then null;end;
end $$;
do $$ declare created uuid;begin
 for i in 1..29 loop created:=(public.manage_work_order(gen_random_uuid(),'create',null,0,'11223300-0000-4000-8000-000000000008',null,'Bounded fixture issue','A detailed description of the bounded issue.','standard','Manager reporting context')->>'id')::uuid;end loop;
 begin perform public.manage_work_order(gen_random_uuid(),'create',null,0,'11223300-0000-4000-8000-000000000008',null,'Above daily limit','A detailed description of the bounded issue.','standard','Manager reporting context');raise exception 'Daily limit bypassed';exception when unique_violation then null;end;
 perform public.manage_work_order(gen_random_uuid(),'cancel',created,1,null,null,null,null,null,'Cancellation remains available');
end $$;
reset role;
do $$ begin
 begin update public.work_orders set unit_id=null where id=current_setting('openhouse.work_order')::uuid;raise exception 'Resource binding changed';exception when unique_violation then null;end;
 begin update public.units set property_id='11223300-0000-4000-8000-000000000009' where id='11223300-0000-4000-8000-000000000010';raise exception 'Unit moved away from history';exception when unique_violation then null;end;
 begin update public.properties set organization_id='11223300-0000-4000-8000-000000000007' where id='11223300-0000-4000-8000-000000000008';raise exception 'Property moved away from history';exception when unique_violation then null;end;
end $$;
set local role authenticated;
do $$ declare caller uuid;begin
 foreach caller in array array['11223300-0000-4000-8000-000000000002'::uuid,'11223300-0000-4000-8000-000000000003'::uuid,'11223300-0000-4000-8000-000000000004'::uuid,'11223300-0000-4000-8000-000000000005'::uuid] loop
 perform set_config('request.jwt.claim.sub',caller::text,true);
 if exists(select 1 from public.work_orders where organization_id='11223300-0000-4000-8000-000000000006') or exists(select 1 from public.work_order_changes where organization_id='11223300-0000-4000-8000-000000000006') then raise exception 'Unauthorized work record visible';end if;
 begin perform public.manage_work_order(gen_random_uuid(),'triage',current_setting('openhouse.work_order')::uuid,3,null,null,null,null,'urgent','Unauthorized transition');raise exception 'Unauthorized transition accepted';exception when insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
set local role anon;
do $$ begin begin perform 1 from public.work_orders;raise exception 'Anonymous work orders visible';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
