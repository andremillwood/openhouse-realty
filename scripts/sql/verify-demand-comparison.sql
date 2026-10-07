begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('99004433-0000-4000-8000-000000000001','view-prospect-one@example.invalid',now()),
 ('99004433-0000-4000-8000-000000000002','view-prospect-two@example.invalid',now()),
 ('99004433-0000-4000-8000-000000000003','view-host-one@example.invalid',now()),
 ('99004433-0000-4000-8000-000000000004','view-host-two@example.invalid',now()),
 ('99004433-0000-4000-8000-000000000005','view-other-staff@example.invalid',now());
insert into public.organizations(id,name) values ('99004433-0000-4000-8000-000000000006','Viewing test one'),('99004433-0000-4000-8000-000000000007','Viewing test two');
insert into public.staff_accounts(user_id,organization_id,role) values
 ('99004433-0000-4000-8000-000000000003','99004433-0000-4000-8000-000000000006','realtor'),
 ('99004433-0000-4000-8000-000000000004','99004433-0000-4000-8000-000000000006','manager'),
 ('99004433-0000-4000-8000-000000000005','99004433-0000-4000-8000-000000000007','realtor');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values
 ('99004433-0000-4000-8000-000000000008','99004433-0000-4000-8000-000000000006','Viewing fixture one','Test','rent','house','published',100,'A sufficiently complete fixture description.','https://example.invalid/fixture.jpg'),
 ('99004433-0000-4000-8000-000000000009','99004433-0000-4000-8000-000000000006','Viewing fixture two','Test','rent','house','published',100,'A sufficiently complete fixture description.','https://example.invalid/fixture.jpg');
select set_config('request.jwt.claim.sub','99004433-0000-4000-8000-000000000003',true);
set local role authenticated;
select public.manage_viewing_slot('create','99004433-0000-4000-8000-000000000010',null,'99004433-0000-4000-8000-000000000008',now()+interval '2 days',now()+interval '2 days 30 minutes');
reset role;
select set_config('report.slot',(select id::text from public.viewing_slots where request_id='99004433-0000-4000-8000-000000000010'),true);
select set_config('request.jwt.claim.sub','99004433-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('report.viewing',public.request_viewing('99004433-0000-4000-8000-000000000011',current_setting('report.slot')::uuid,null,'Report Prospect','',true)::text,true);
select public.submit_enquiry('99004433-0000-4000-8000-000000000012','99004433-0000-4000-8000-000000000008',null,'Report Prospect','','Please help me with this property enquiry.',true);
select set_config('request.jwt.claim.sub','99004433-0000-4000-8000-000000000003',true);
select public.transition_viewing(current_setting('report.viewing')::uuid,'confirm','');
select public.transition_viewing(current_setting('report.viewing')::uuid,'confirm','');
select public.transition_viewing(current_setting('report.viewing')::uuid,'cancel','Report fixture cancellation');
select public.transition_viewing(current_setting('report.viewing')::uuid,'cancel','Report fixture cancellation');
do $$ declare start_at timestamptz; end_at timestamptz; n integer; begin
 start_at:=date_trunc('day',now() at time zone 'America/Jamaica') at time zone 'America/Jamaica';end_at:=start_at+interval '1 day';
 if (select count(*) from public.enquiries where organization_id='99004433-0000-4000-8000-000000000006' and status='new' and created_at>=start_at and created_at<end_at)<>1 then raise exception 'Enquiry cohort count mismatch';end if;
 if (select count(*) from public.viewings where organization_id='99004433-0000-4000-8000-000000000006' and status='cancelled' and created_at>=start_at and created_at<end_at)<>1 then raise exception 'Viewing cohort count mismatch';end if;
 select count(*) into n from public.viewing_events e join public.viewings v on v.id=e.viewing_id where v.organization_id='99004433-0000-4000-8000-000000000006' and e.event_name='confirm' and e.created_at>=start_at and e.created_at<end_at;
 if n<>1 then raise exception 'Confirmation audit count mismatch';end if;
 select count(*) into n from public.viewing_events e join public.viewings v on v.id=e.viewing_id where v.organization_id='99004433-0000-4000-8000-000000000006' and e.event_name='cancel' and e.created_at>=start_at and e.created_at<end_at;
 if n<>1 then raise exception 'Cancellation audit count mismatch';end if;
 if exists(select 1 from public.viewing_events e join public.viewings v on v.id=e.viewing_id where v.organization_id='99004433-0000-4000-8000-000000000006' and e.created_at>=end_at and e.created_at<end_at+interval '1 day') then raise exception 'Events leaked into next period';end if;
end $$;
select set_config('request.jwt.claim.sub','99004433-0000-4000-8000-000000000004',true);
do $$ begin if (select count(*) from public.viewing_events e join public.viewings v on v.id=e.viewing_id where v.organization_id='99004433-0000-4000-8000-000000000006' and e.event_name='confirm')<>1 then raise exception 'Manager count denied';end if;end $$;
select set_config('request.jwt.claim.sub','99004433-0000-4000-8000-000000000005',true);
do $$ begin if exists(select 1 from public.viewing_events e join public.viewings v on v.id=e.viewing_id where v.organization_id='99004433-0000-4000-8000-000000000006') then raise exception 'Foreign organization activity read accepted';end if;if exists(select 1 from public.enquiries where organization_id='99004433-0000-4000-8000-000000000006') then raise exception 'Foreign enquiry count read accepted';end if;end $$;
reset role;
select set_config('request.jwt.claim.sub','99004433-0000-4000-8000-000000000003',true);
-- Only synthetic fixture timestamps are moved to exact Jamaica boundaries.
-- Existing workflow events are retained; this is a rolled-back reporting fixture.
update public.enquiries set created_at='2026-10-01T04:59:59.999999Z' where organization_id='99004433-0000-4000-8000-000000000006';
update public.viewings set created_at='2026-10-08T04:59:59.999999Z' where organization_id='99004433-0000-4000-8000-000000000006';
update public.viewing_events set created_at=case when event_name='confirm' then '2026-09-24T05:00:00Z'::timestamptz when event_name='cancel' then '2026-10-01T05:00:00Z'::timestamptz else '2026-09-24T04:59:59.999999Z'::timestamptz end where viewing_id=current_setting('report.viewing')::uuid;
select set_config('request.jwt.claim.sub','99004433-0000-4000-8000-000000000003',true);
set local role authenticated;
do $$ declare caller uuid; begin
 foreach caller in array array['99004433-0000-4000-8000-000000000003'::uuid,'99004433-0000-4000-8000-000000000004'::uuid] loop
 perform set_config('request.jwt.claim.sub',caller::text,true);
 if (select count(*) from public.enquiries where organization_id='99004433-0000-4000-8000-000000000006' and status='new' and created_at>='2026-09-24T00:00:00-05:00' and created_at<'2026-10-01T00:00:00-05:00')<>1 then raise exception 'Previous enquiry cohort missing';end if;
 if (select count(*) from public.enquiries where organization_id='99004433-0000-4000-8000-000000000006' and status='new' and created_at>='2026-10-01T00:00:00-05:00' and created_at<'2026-10-08T00:00:00-05:00')<>0 then raise exception 'Previous enquiry crossed boundary';end if;
 if (select count(*) from public.viewings where organization_id='99004433-0000-4000-8000-000000000006' and status='cancelled' and created_at>='2026-10-01T00:00:00-05:00' and created_at<'2026-10-08T00:00:00-05:00')<>1 then raise exception 'Selected viewing cohort missing';end if;
 if (select count(*) from public.viewings where organization_id='99004433-0000-4000-8000-000000000006' and status='cancelled' and created_at>='2026-09-24T00:00:00-05:00' and created_at<'2026-10-01T00:00:00-05:00')<>0 then raise exception 'Selected viewing crossed boundary';end if;
 if (select count(*) from public.viewing_events e join public.viewings v on v.id=e.viewing_id where v.organization_id='99004433-0000-4000-8000-000000000006' and e.event_name='confirm' and e.created_at>='2026-09-24T00:00:00-05:00' and e.created_at<'2026-10-01T00:00:00-05:00')<>1 then raise exception 'Previous confirmation missing';end if;
 if (select count(*) from public.viewing_events e join public.viewings v on v.id=e.viewing_id where v.organization_id='99004433-0000-4000-8000-000000000006' and e.event_name='cancel' and e.created_at>='2026-10-01T00:00:00-05:00' and e.created_at<'2026-10-08T00:00:00-05:00')<>1 then raise exception 'Selected cancellation missing';end if;
 if (select count(*) from public.viewing_events e join public.viewings v on v.id=e.viewing_id where v.organization_id='99004433-0000-4000-8000-000000000006' and e.event_name='cancel' and e.created_at>='2026-09-24T00:00:00-05:00' and e.created_at<'2026-10-01T00:00:00-05:00')<>0 then raise exception 'Cancellation overlapped previous period';end if;
 if (select count(*) from public.viewing_events e join public.viewings v on v.id=e.viewing_id where v.organization_id='99004433-0000-4000-8000-000000000006' and e.created_at>='2026-10-08T00:00:00-05:00')<>0 then raise exception 'Events outside range';end if;
 end loop;
 perform set_config('request.jwt.claim.sub','99004433-0000-4000-8000-000000000005',true);
 if exists(select 1 from public.enquiries where organization_id='99004433-0000-4000-8000-000000000006' and created_at>='2026-09-24T00:00:00-05:00' and created_at<'2026-10-08T00:00:00-05:00') then raise exception 'Foreign comparison enquiries leaked';end if;
 if exists(select 1 from public.viewing_events e join public.viewings v on v.id=e.viewing_id where v.organization_id='99004433-0000-4000-8000-000000000006' and e.created_at>='2026-09-24T00:00:00-05:00' and e.created_at<'2026-10-08T00:00:00-05:00') then raise exception 'Foreign comparison events leaked';end if;
end $$;
reset role;
rollback;
select 'PASS: authenticated realtor/manager comparison cohorts and recorded event periods, exact Jamaica boundaries and foreign isolation; synthetic timestamps rolled back, no worker or delivery.' as verification;
