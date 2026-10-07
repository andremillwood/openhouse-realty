begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('55667788-0000-4000-8000-000000000001','applicant@example.invalid',now()),
 ('55667788-0000-4000-8000-000000000002','other@example.invalid',now()),
 ('55667788-0000-4000-8000-000000000003','reviewer@example.invalid',now()),
 ('55667788-0000-4000-8000-000000000004','foreign@example.invalid',now()),
 ('55667788-0000-4000-8000-000000000005','unverified@example.invalid',null);
insert into public.organizations(id,name) values ('55667788-0000-4000-8000-000000000006','Application fixtures'),('55667788-0000-4000-8000-000000000007','Foreign application fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
 ('55667788-0000-4000-8000-000000000003','55667788-0000-4000-8000-000000000006','manager'),
 ('55667788-0000-4000-8000-000000000004','55667788-0000-4000-8000-000000000007','admin'),
 ('55667788-0000-4000-8000-000000000005','55667788-0000-4000-8000-000000000006','realtor'),
 ('55667788-0000-4000-8000-000000000001','55667788-0000-4000-8000-000000000006','realtor');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values
 ('55667788-0000-4000-8000-000000000008','55667788-0000-4000-8000-000000000006','Rental fixture','Kingston','rent','house','published',100000,'Approved rental fixture description.','https://example.invalid/approved.jpg'),
 ('55667788-0000-4000-8000-000000000009','55667788-0000-4000-8000-000000000006','Sale fixture','Kingston','sale','house','published',10000000,'Approved sale fixture description.','https://example.invalid/approved.jpg'),
 ('55667788-0000-4000-8000-000000000010','55667788-0000-4000-8000-000000000006','Draft rental fixture','Kingston','rent','house','draft',100000,'','');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url)
select ('55667788-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'55667788-0000-4000-8000-000000000006','Additional rental '||i,'Kingston','rent','house','published',100000,'Approved additional rental description.','https://example.invalid/approved.jpg' from generate_series(51,53) i;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.test_enquiry',public.submit_enquiry('55667788-0000-4000-8000-000000000011','55667788-0000-4000-8000-000000000008',null,'Test Applicant','','Please discuss this rental property.',true)::text,true);
do $$ declare app uuid;retry uuid; move date:=(now() at time zone 'America/Jamaica')::date+30;begin
 app:=public.submit_rental_application('55667788-0000-4000-8000-000000000012','55667788-0000-4000-8000-000000000008',current_setting('openhouse.test_enquiry')::uuid,'Test Applicant','',2,move,'Please review my rental application.',true);
 perform set_config('openhouse.test_application',app::text,true);
 retry:=public.submit_rental_application('55667788-0000-4000-8000-000000000012','55667788-0000-4000-8000-000000000008',current_setting('openhouse.test_enquiry')::uuid,'Test Applicant','',2,move,'Please review my rental application.',true);
 if app<>retry or (select count(*) from public.rental_applications)<>1 then raise exception 'Duplicate application';end if;
 if not exists(select 1 from public.rental_applications where id=app and contact_email='applicant@example.invalid' and organization_id='55667788-0000-4000-8000-000000000006' and rent_jmd_snapshot=100000 and version=1) then raise exception 'Trusted application identity/quote failure';end if;
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000012','55667788-0000-4000-8000-000000000008',current_setting('openhouse.test_enquiry')::uuid,'Changed Applicant','',2,move,'Please review my rental application.',true);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000013','55667788-0000-4000-8000-000000000008',null,'Test Applicant','',2,move,'Please review my rental application.',true);raise exception 'Second active application accepted';exception when unique_violation then null;end;
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000013','55667788-0000-4000-8000-000000000009',null,'Test Applicant','',2,move,'Please review my rental application.',true);raise exception 'Sale application accepted';exception when invalid_parameter_value then null;end;
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000013','55667788-0000-4000-8000-000000000010',null,'Test Applicant','',2,move,'Please review my rental application.',true);raise exception 'Unpublished application accepted';exception when invalid_parameter_value then null;end;
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000013','55667788-0000-4000-8000-000000000008',null,'Test Applicant','',2,move,'Please review my rental application.',false);raise exception 'Missing consent accepted';exception when invalid_parameter_value then null;end;
 begin update public.rental_applications set status='approved';raise exception 'Direct applicant approval allowed';exception when insufficient_privilege then null;end;
 begin perform public.transition_rental_application(app,'55667788-0000-4000-8000-000000000014',1,'start_review','Self review attempt.');raise exception 'Applicant reviewed own application using staff role';exception when insufficient_privilege then null;end;
end $$;
update public.listings set title='Edited after application',price_jmd=120000 where id='55667788-0000-4000-8000-000000000008';
do $$ begin if not exists(select 1 from public.rental_applications where id=current_setting('openhouse.test_application')::uuid and title_snapshot='Rental fixture' and rent_jmd_snapshot=100000) then raise exception 'Later catalog edits changed application quote';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin
 if exists(select 1 from public.rental_applications) or exists(select 1 from public.rental_application_events) then raise exception 'Cross-applicant application/history disclosure';end if;
 begin perform public.transition_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000015',1,'withdraw','Other applicant withdraw.');raise exception 'Cross-applicant transition allowed';exception when insufficient_privilege then null;end;
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000016','55667788-0000-4000-8000-000000000008',current_setting('openhouse.test_enquiry')::uuid,'Other Applicant','',2,(now() at time zone 'America/Jamaica')::date+30,'Please review my rental application.',true);raise exception 'Foreign enquiry linked to application';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.rental_applications) then raise exception 'Foreign organization application read allowed';end if;
 begin perform public.transition_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000017',1,'start_review','Foreign staff review.');raise exception 'Foreign review allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ declare app uuid:=current_setting('openhouse.test_application')::uuid; result jsonb;begin
 result:=public.transition_rental_application(app,'55667788-0000-4000-8000-000000000018',1,'start_review','Reviewing applicant details.');
 if result->>'status'<>'under_review' or (result->>'version')::integer<>2 then raise exception 'Review transition/version failure';end if;
 perform public.transition_rental_application(app,'55667788-0000-4000-8000-000000000018',1,'start_review','Reviewing applicant details.');
 if (select count(*) from public.rental_application_events where application_id=app)<>2 then raise exception 'Duplicate review audit';end if;
 begin perform public.transition_rental_application(app,'55667788-0000-4000-8000-000000000019',1,'request_info','Please clarify your move-in timing.');raise exception 'Stale review overwrite allowed';exception when serialization_failure then null;end;
 begin perform public.transition_rental_application(app,'55667788-0000-4000-8000-000000000019',2,'approve','Approve without document verification.');raise exception 'Premature application approval allowed';exception when invalid_parameter_value then null;end;
 perform public.transition_rental_application(app,'55667788-0000-4000-8000-000000000019',2,'request_info','Please clarify your move-in timing.');
 begin perform public.transition_rental_application(app,'55667788-0000-4000-8000-000000000020',3,'reply','Staff impersonating applicant.');raise exception 'Staff applicant reply allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
select public.transition_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000020',3,'reply','My intended move-in date is flexible by one week.');
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.transition_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000021',4,'start_review','Reviewing the applicant clarification.');
select public.transition_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000022',5,'reject','The required move-in timing cannot be accommodated.');
do $$ begin
 if (select status from public.rental_applications where id=current_setting('openhouse.test_application')::uuid)<>'rejected' then raise exception 'Shared decision not recorded';end if;
 begin perform public.transition_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000023',6,'start_review','Reopening terminal request.');raise exception 'Terminal application reopened';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
do $$ declare app uuid; i integer; move date:=(now() at time zone 'America/Jamaica')::date+30;begin
 app:=public.submit_rental_application('55667788-0000-4000-8000-000000000024','55667788-0000-4000-8000-000000000008',null,'Test Applicant','',2,move,'Please review my new rental application.',true);
 perform public.transition_rental_application(app,'55667788-0000-4000-8000-000000000025',1,'withdraw','Applicant changed their plans.');
 for i in 30..32 loop
  app:=public.submit_rental_application(('55667788-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'55667788-0000-4000-8000-000000000008',null,'Test Applicant','',2,move,'Please review my new rental application.',true);
  perform public.transition_rental_application(app,('55667788-0000-4000-8000-'||lpad((i+10)::text,12,'0'))::uuid,1,'withdraw','Applicant changed their plans.');
 end loop;
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000033','55667788-0000-4000-8000-000000000008',null,'Test Applicant','',2,move,'Please review my new rental application.',true);raise exception 'Sixth daily application accepted' using errcode='XX000';exception when raise_exception then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ declare move date:=(now() at time zone 'America/Jamaica')::date+30;begin
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000060','55667788-0000-4000-8000-000000000008',null,'Other Applicant','',2,(now() at time zone 'America/Jamaica')::date-1,'Please review my rental application.',true);raise exception 'Past date accepted';exception when invalid_parameter_value then null;end;
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000060','55667788-0000-4000-8000-000000000008',null,'Other Applicant','',2,(now() at time zone 'America/Jamaica')::date+366,'Please review my rental application.',true);raise exception 'Remote future date accepted';exception when invalid_parameter_value then null;end;
 perform public.submit_rental_application('55667788-0000-4000-8000-000000000060','55667788-0000-4000-8000-000000000008',null,'Other Applicant','',2,move,'Please review my rental application.',true);
 perform public.submit_rental_application('55667788-0000-4000-8000-000000000061','55667788-0000-4000-8000-000000000051',null,'Other Applicant','',2,move,'Please review my rental application.',true);
 perform public.submit_rental_application('55667788-0000-4000-8000-000000000062','55667788-0000-4000-8000-000000000052',null,'Other Applicant','',2,move,'Please review my rental application.',true);
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000063','55667788-0000-4000-8000-000000000053',null,'Other Applicant','',2,move,'Please review my rental application.',true);raise exception 'Fourth active application accepted' using errcode='XX000';exception when raise_exception then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin
 if exists(select 1 from public.rental_applications) then raise exception 'Unverified staff application read';end if;
 begin perform public.submit_rental_application('55667788-0000-4000-8000-000000000034','55667788-0000-4000-8000-000000000008',null,'Unverified Applicant','',2,(now() at time zone 'America/Jamaica')::date+30,'Please review my new rental application.',true);raise exception 'Unverified application accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ declare app uuid:=current_setting('openhouse.test_application')::uuid;begin
 if (select count(*) from private.notification_outbox where application_event_id in(select id from public.rental_application_events where application_id=app) and state='pending')<>2 then raise exception 'Obsolete application notices were not superseded';end if;
 if not exists(select 1 from private.notification_outbox where application_event_id in(select id from public.rental_application_events where application_id=app) and recipient='applicant@example.invalid' and subject_snapshot like 'Application rejected:%' and position('cannot be accommodated' in text_snapshot)>0) then raise exception 'Frozen applicant decision notice missing';end if;
end $$;
set local role anon;
do $$ begin
 begin perform count(*) from public.rental_applications;raise exception 'Anonymous application reads allowed';exception when insufficient_privilege then null;end;
 begin perform public.transition_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000050',6,'reply','Anonymous reply attempt.');raise exception 'Anonymous application RPC allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role service_role;
do $$ declare batch integer;claimed integer:=0;job record;begin
 loop
  batch:=0;
  for job in select * from public.claim_enquiry_notifications('sender@example.invalid','business@example.invalid') loop
   batch:=batch+1;
   if job.subject_snapshot like 'Application %' then
    claimed:=claimed+1;
    if job.recipient not in('business@example.invalid','applicant@example.invalid','other@example.invalid') or job.text_snapshot is null or position('Event time (Jamaica)' in job.text_snapshot)=0 then raise exception 'Application queue payload/recipient failure';end if;
   end if;
  end loop;
  exit when batch=0;
 end loop;
 if claimed<>16 then raise exception 'Generic worker did not claim all current application audiences: %',claimed;end if;
end $$;
reset role;
rollback;
select 'PASS: verified rental eligibility/identity/consent/quote/enquiry linkage, idempotency/active uniqueness/daily limits, private history, independent review, stale state/reply/rejection/withdrawal audit and superseded frozen applicant notifications. Fixtures rolled back; no email sent.' as verification;
