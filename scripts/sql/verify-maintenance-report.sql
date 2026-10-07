begin;
insert into auth.users(id,email,email_confirmed_at) values
('88004433-0000-4000-8000-000000000001','work-manager@example.invalid',now()),
('88004433-0000-4000-8000-000000000002','work-realtor@example.invalid',now()),
('88004433-0000-4000-8000-000000000003','work-foreign@example.invalid',now()),
('88004433-0000-4000-8000-000000000004','work-unverified@example.invalid',null),
('88004433-0000-4000-8000-000000000005','work-prospect@example.invalid',now());
insert into public.organizations(id,name) values('88004433-0000-4000-8000-000000000006','Work order fixtures'),('88004433-0000-4000-8000-000000000007','Foreign work order fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
('88004433-0000-4000-8000-000000000001','88004433-0000-4000-8000-000000000006','manager'),
('88004433-0000-4000-8000-000000000002','88004433-0000-4000-8000-000000000006','realtor'),
('88004433-0000-4000-8000-000000000003','88004433-0000-4000-8000-000000000007','admin'),
('88004433-0000-4000-8000-000000000004','88004433-0000-4000-8000-000000000006','manager');
insert into public.properties(id,organization_id,name) values('88004433-0000-4000-8000-000000000008','88004433-0000-4000-8000-000000000006','Managed fixture'),('88004433-0000-4000-8000-000000000009','88004433-0000-4000-8000-000000000007','Foreign fixture');
insert into public.units(id,property_id,unit_label) values('88004433-0000-4000-8000-000000000010','88004433-0000-4000-8000-000000000008','A'),('88004433-0000-4000-8000-000000000011','88004433-0000-4000-8000-000000000009','Foreign A');
select set_config('request.jwt.claim.sub','88004433-0000-4000-8000-000000000001',true);
set local role authenticated;
select public.manage_work_order('88004433-0000-4000-8000-000000000012','create',null,0,'88004433-0000-4000-8000-000000000008',null,'Urgent fixture','A detailed description for report verification.','urgent','Recorded fixture intake');
select public.manage_work_order('88004433-0000-4000-8000-000000000013','create',null,0,'88004433-0000-4000-8000-000000000008',null,'High fixture','A detailed description for report verification.','high','Recorded fixture intake');
select set_config('report.cancelled',public.manage_work_order('88004433-0000-4000-8000-000000000014','create',null,0,'88004433-0000-4000-8000-000000000008',null,'Cancelled urgent fixture','A detailed description for report verification.','urgent','Recorded fixture intake')->>'id',true);
select public.manage_work_order('88004433-0000-4000-8000-000000000015','cancel',current_setting('report.cancelled')::uuid,1,null,null,null,null,null,'Fixture cancellation decision');
do $$ declare start_at timestamptz;end_at timestamptz;begin
 start_at:=date_trunc('day',now() at time zone 'America/Jamaica') at time zone 'America/Jamaica';end_at:=start_at+interval '1 day';
 if (select count(*) from public.work_orders where organization_id='88004433-0000-4000-8000-000000000006' and status='reported' and created_at>=start_at and created_at<end_at)<>2 then raise exception 'Reported cohort count mismatch';end if;
 if (select count(*) from public.work_orders where organization_id='88004433-0000-4000-8000-000000000006' and status='cancelled')<>1 then raise exception 'Cancelled state count mismatch';end if;
 if (select count(*) from public.work_orders where organization_id='88004433-0000-4000-8000-000000000006' and priority='urgent' and status in('reported','triaged','assigned','scheduled','on_site','in_progress'))<>1 then raise exception 'Cancelled urgent work included in open priority';end if;
 if (select count(*) from public.work_orders where organization_id='88004433-0000-4000-8000-000000000006' and priority='high' and status in('reported','triaged','assigned','scheduled','on_site','in_progress'))<>1 then raise exception 'High open priority count mismatch';end if;
 if exists(select 1 from public.work_orders where organization_id='88004433-0000-4000-8000-000000000006' and created_at>=end_at and created_at<end_at+interval '1 day') then raise exception 'Report cohort leaked into next period';end if;
end $$;
do $$ declare caller uuid;begin
 foreach caller in array array['88004433-0000-4000-8000-000000000002'::uuid,'88004433-0000-4000-8000-000000000003'::uuid,'88004433-0000-4000-8000-000000000004'::uuid,'88004433-0000-4000-8000-000000000005'::uuid] loop
 perform set_config('request.jwt.claim.sub',caller::text,true);
 if exists(select 1 from public.work_orders where organization_id='88004433-0000-4000-8000-000000000006') then raise exception 'Unauthorized reporting record visible';end if;
 end loop;
end $$;
reset role;
rollback;
select 'PASS: management maintenance state/priority counts, cancelled-open exclusion, Jamaica cohort periods and realtor/foreign/unverified/prospect isolation. Fixtures rolled back.' as verification;
