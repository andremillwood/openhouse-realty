begin;
insert into auth.users(id,email,email_confirmed_at) values
('77005544-0000-4000-8000-000000000001','contractor-manager@example.invalid',now()),
('77005544-0000-4000-8000-000000000002','contractor-target@example.invalid',now()),
('77005544-0000-4000-8000-000000000003','contractor-unverified@example.invalid',null),
('77005544-0000-4000-8000-000000000004','contractor-foreign@example.invalid',now()),
('77005544-0000-4000-8000-000000000005','contractor-realtor@example.invalid',now()),
('77005544-0000-4000-8000-000000000006','contractor-prospect@example.invalid',now());
insert into public.organizations(id,name) values('77005544-0000-4000-8000-000000000007','Contractor fixtures'),('77005544-0000-4000-8000-000000000008','Foreign contractor fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
('77005544-0000-4000-8000-000000000001','77005544-0000-4000-8000-000000000007','manager'),
('77005544-0000-4000-8000-000000000003','77005544-0000-4000-8000-000000000007','manager'),
('77005544-0000-4000-8000-000000000004','77005544-0000-4000-8000-000000000008','manager'),
('77005544-0000-4000-8000-000000000005','77005544-0000-4000-8000-000000000007','realtor');

insert into public.properties(id,organization_id,name) values('77005544-0000-4000-8000-000000000010','77005544-0000-4000-8000-000000000007','Offer fixture');
select set_config('request.jwt.claim.sub','77005544-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.contractor',public.author_contractor_account(gen_random_uuid(),null,0,'contractor-target@example.invalid','Approved Contractor',array['Plumbing'],true,'Approved registration',true)->>'id',true);
select set_config('openhouse.job',public.manage_work_order(gen_random_uuid(),'create',null,0,'77005544-0000-4000-8000-000000000010',null,'Private issue','Internal details are not shared with contractors.','standard','Internal management reason')->>'id',true);
select public.manage_work_order(gen_random_uuid(),'triage',current_setting('openhouse.job')::uuid,1,null,null,null,null,'standard','Ready for approved scope');
select set_config('openhouse.offer',public.manage_contractor_work_offer('77005544-0000-4000-8000-000000000011','offer',null,current_setting('openhouse.job')::uuid,current_setting('openhouse.contractor')::uuid,0,2,'Plumbing assessment','Assess the approved kitchen plumbing issue.','Plumbing','Approved scope reviewed',true)->>'id',true);
do $$ begin if (select count(*) from public.contractor_work_offers where organization_id='77005544-0000-4000-8000-000000000007' and state='offered')<>1 then raise exception 'Management offered count mismatch';end if;end $$;
select set_config('request.jwt.claim.sub','77005544-0000-4000-8000-000000000002',true);
select public.manage_contractor_work_offer(gen_random_uuid(),'accept',current_setting('openhouse.offer')::uuid,null,null,1,null,null,null,null,'Accept approved work',null);
select set_config('request.jwt.claim.sub','77005544-0000-4000-8000-000000000001',true);
select set_config('openhouse.visit',public.manage_contractor_visit('77005544-0000-4000-8000-000000000020','propose',null,current_setting('openhouse.offer')::uuid,0,2,now()+interval '2 days',now()+interval '2 days 1 hour','Approved appointment note','Proposed after management review',true)->>'id',true);
do $$ begin if (select count(*) from public.contractor_visits where organization_id='77005544-0000-4000-8000-000000000007' and state='proposed')<>1 then raise exception 'Proposed visit count mismatch';end if;end $$;
select set_config('request.jwt.claim.sub','77005544-0000-4000-8000-000000000002',true);
select public.manage_contractor_visit('77005544-0000-4000-8000-000000000021','confirm',current_setting('openhouse.visit')::uuid,null,1,null,null,null,null,'Confirmed appointment window',null);
select public.manage_contractor_visit('77005544-0000-4000-8000-000000000021','confirm',current_setting('openhouse.visit')::uuid,null,1,null,null,null,null,'Confirmed appointment window',null);
select set_config('request.jwt.claim.sub','77005544-0000-4000-8000-000000000001',true);
do $$ declare start_at timestamptz;end_at timestamptz;begin
 start_at:=date_trunc('day',now() at time zone 'America/Jamaica') at time zone 'America/Jamaica';end_at:=start_at+interval '1 day';
 if (select count(*) from public.contractor_work_offers where organization_id='77005544-0000-4000-8000-000000000007' and state='accepted' and created_at>=start_at and created_at<end_at)<>1 then raise exception 'Accepted cohort count mismatch';end if;
 if (select count(*) from public.contractor_visits where organization_id='77005544-0000-4000-8000-000000000007' and state='confirmed' and created_at>=start_at and created_at<end_at)<>1 then raise exception 'Confirmed cohort count mismatch';end if;
 if exists(select 1 from public.contractor_visits where organization_id='77005544-0000-4000-8000-000000000007' and created_at>=end_at and created_at<end_at+interval '1 day') then raise exception 'Creation cohort used future appointment time';end if;
end $$;
do $$ declare caller uuid;begin
 foreach caller in array array['77005544-0000-4000-8000-000000000003'::uuid,'77005544-0000-4000-8000-000000000004'::uuid,'77005544-0000-4000-8000-000000000005'::uuid,'77005544-0000-4000-8000-000000000006'::uuid] loop
 perform set_config('request.jwt.claim.sub',caller::text,true);
 if exists(select 1 from public.contractor_work_offers where organization_id='77005544-0000-4000-8000-000000000007') or exists(select 1 from public.contractor_visits where organization_id='77005544-0000-4000-8000-000000000007') then raise exception 'Unauthorized coordination report record visible';end if;
 end loop;
end $$;
reset role;
rollback;
select 'PASS: manager offer/visit counts, exact confirmation retry, creation-date cohorts and unverified/foreign/realtor/prospect isolation. Fixtures rolled back; no delivery invoked.' as verification;
