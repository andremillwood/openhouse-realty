begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('66117788-0000-4000-8000-000000000001','applicant@example.invalid',now()),
 ('66117788-0000-4000-8000-000000000002','other@example.invalid',now()),
 ('66117788-0000-4000-8000-000000000003','reviewer@example.invalid',now()),
 ('66117788-0000-4000-8000-000000000004','foreign@example.invalid',now()),
 ('66117788-0000-4000-8000-000000000005','unverified@example.invalid',null);
insert into public.organizations(id,name) values ('66117788-0000-4000-8000-000000000006','Application fixtures'),('66117788-0000-4000-8000-000000000007','Foreign application fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
 ('66117788-0000-4000-8000-000000000003','66117788-0000-4000-8000-000000000006','manager'),
 ('66117788-0000-4000-8000-000000000004','66117788-0000-4000-8000-000000000007','admin'),
 ('66117788-0000-4000-8000-000000000005','66117788-0000-4000-8000-000000000006','realtor'),
 ('66117788-0000-4000-8000-000000000001','66117788-0000-4000-8000-000000000006','realtor');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values
 ('66117788-0000-4000-8000-000000000008','66117788-0000-4000-8000-000000000006','Rental fixture','Kingston','rent','house','published',100000,'Approved rental fixture description.','https://example.invalid/approved.jpg'),
 ('66117788-0000-4000-8000-000000000009','66117788-0000-4000-8000-000000000006','Sale fixture','Kingston','sale','house','published',10000000,'Approved sale fixture description.','https://example.invalid/approved.jpg'),
 ('66117788-0000-4000-8000-000000000010','66117788-0000-4000-8000-000000000006','Draft rental fixture','Kingston','rent','house','draft',100000,'','');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url)
select ('66117788-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'66117788-0000-4000-8000-000000000006','Additional rental '||i,'Kingston','rent','house','published',100000,'Approved additional rental description.','https://example.invalid/approved.jpg' from generate_series(51,53) i;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.test_application',public.submit_rental_application('66117788-0000-4000-8000-000000000012','66117788-0000-4000-8000-000000000008',null,'Test Applicant','',2,(now() at time zone 'America/Jamaica')::date+30,'Please review my rental application.',true)::text,true);
select set_config('openhouse.test_document',public.reserve_application_document(current_setting('openhouse.test_application')::uuid,'66117788-0000-4000-8000-000000000013','identity','identity.pdf','application/pdf',20)::text,true);
do $$ declare doc jsonb:=current_setting('openhouse.test_document')::jsonb;retry jsonb;begin
 retry:=public.reserve_application_document(current_setting('openhouse.test_application')::uuid,'66117788-0000-4000-8000-000000000013','identity','identity.pdf','application/pdf',20);
 if doc<>retry then raise exception 'Reservation retry differs';end if;
 if not private.application_document_storage_access(doc->>'path','insert') then raise exception 'Owner cannot upload reserved path';end if;
 begin perform public.finish_application_document(auth.uid(),(doc->>'id')::uuid,20,'application/pdf',repeat('a',64));raise exception 'Applicant certified file';exception when insufficient_privilege then null;end;
 begin update public.application_documents set state='uploaded';raise exception 'Applicant updated metadata';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000003',true);
do $$ begin if exists(select 1 from public.application_documents) or private.application_document_storage_access(current_setting('openhouse.test_document')::jsonb->>'path','read') then raise exception 'Staff saw unfinished file';end if;end $$;
reset role;
set local role service_role;
select public.finish_application_document('66117788-0000-4000-8000-000000000001',(current_setting('openhouse.test_document')::jsonb->>'id')::uuid,20,'application/pdf',repeat('a',64));
select public.finish_application_document('66117788-0000-4000-8000-000000000001',(current_setting('openhouse.test_document')::jsonb->>'id')::uuid,20,'application/pdf',repeat('a',64));
reset role;
set local role authenticated;
select public.transition_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),1,'start_review','Reviewing evidence before approval.');
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),2,1,'Approved following the business process.','Eligibility file reference A1',true,true);raise exception 'Unconfigured policy approval';exception when invalid_parameter_value then null;end;
end $$;
reset role;
insert into auth.users(id,email,email_confirmed_at) values('66117788-0000-4000-8000-000000000020','admin@example.invalid',now());
insert into public.staff_accounts(user_id,organization_id,role) values('66117788-0000-4000-8000-000000000020','66117788-0000-4000-8000-000000000006','admin');
insert into public.properties(id,organization_id,name,area,address_text) values('66117788-0000-4000-8000-000000000030','66117788-0000-4000-8000-000000000006','Managed fixture','Kingston','Private fixture address');
insert into public.units(id,property_id,unit_label) values('66117788-0000-4000-8000-000000000031','66117788-0000-4000-8000-000000000030','Unit A');
update public.listings set property_id='66117788-0000-4000-8000-000000000030',unit_id='66117788-0000-4000-8000-000000000031' where id in('66117788-0000-4000-8000-000000000008','66117788-0000-4000-8000-000000000051');
set local role authenticated;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000020',true);
select public.configure_rental_approval_policy('66117788-0000-4000-8000-000000000032',0,array['identity'],1,array['manager'],'Approved business fixture policy A',true);
select public.configure_rental_approval_policy('66117788-0000-4000-8000-000000000032',0,array['identity'],1,array['manager'],'Approved business fixture policy A',true);
do $$ begin
 if (select count(*) from public.rental_approval_policies)<>1 then raise exception 'Policy retry duplicated';end if;
 begin perform public.configure_rental_approval_policy(gen_random_uuid(),0,array['identity'],1,array['manager'],'Changed policy reference',true);raise exception 'Stale policy accepted';exception when serialization_failure then null;end;
 begin perform public.configure_rental_approval_policy(gen_random_uuid(),1,array['identity'],1,array['manager'],'Unapproved policy reference',false);raise exception 'Unapproved policy accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.configure_rental_approval_policy(gen_random_uuid(),1,array['identity'],1,array['manager'],'Manager policy edit attempt',true);raise exception 'Manager configured policy';exception when insufficient_privilege then null;end;
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),2,1,'Approved following the business process.','Eligibility file reference A1',true,true);raise exception 'Unverified documents approved';exception when invalid_parameter_value then null;end;
end $$;
select public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,gen_random_uuid(),0,'verified','Identity source confirmed for fixture.');
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),2,1,'Approved following the business process.','Eligibility file reference A1',true,true);raise exception 'Missing cosigner approved';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000001',true);
select set_config('openhouse.test_cosigner',public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'other@example.invalid',true)::text,true);
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000002',true);
select public.respond_application_cosigner(current_setting('openhouse.test_cosigner')::uuid,gen_random_uuid(),1,'accept',true);
reset role;
insert into public.staff_accounts(user_id,organization_id,role) values('66117788-0000-4000-8000-000000000002','66117788-0000-4000-8000-000000000006','manager');
set local role authenticated;
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Co-signer staff approval attempted.','Co-signer evidence reference',true,true);raise exception 'Participating co-signer approved own involvement';exception when insufficient_privilege then null;end;
end $$;
reset role;
delete from public.staff_accounts where user_id='66117788-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.rental_approval_policies) then raise exception 'Foreign policy disclosure';end if;
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Foreign staff approval attempted.','Foreign eligibility reference',true,true);raise exception 'Foreign approval accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000001',true);
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Applicant self approval attempted.','Applicant eligibility reference',true,true);raise exception 'Self approval accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000002',true);
select set_config('openhouse.test_competing',public.submit_rental_application(gen_random_uuid(),'66117788-0000-4000-8000-000000000051',null,'Competing Applicant','',2,(now() at time zone 'America/Jamaica')::date+30,'Please review the other listing of this unit.',true)::text,true);
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000003',true);
reset role;
do $$ begin
 update public.listings set price_jmd=110000 where id='66117788-0000-4000-8000-000000000008';
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Approval with changed terms.','Eligibility source A1',true,true);raise exception 'Changed rent terms approved';exception when invalid_parameter_value then null;end;
 update public.listings set price_jmd=100000,unit_id=null where id='66117788-0000-4000-8000-000000000008';
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Approval without a managed unit.','Eligibility source A1',true,true);raise exception 'Unbound listing approved';exception when invalid_parameter_value then null;end;
 update public.listings set unit_id='66117788-0000-4000-8000-000000000031' where id='66117788-0000-4000-8000-000000000008';
end $$;
set local role authenticated;
do $$ declare result jsonb;begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Incomplete checks approval attempt.','Eligibility file reference A1',false,true);raise exception 'Missing eligibility check approved';exception when invalid_parameter_value then null;end;
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),3,1,'Stale approval attempted.','Eligibility file reference A1',true,true);raise exception 'Stale application approved';exception when serialization_failure then null;end;
 result:=public.approve_rental_application(current_setting('openhouse.test_application')::uuid,'66117788-0000-4000-8000-000000000033',4,1,'Approved following the business process.','Eligibility file reference A1',true,true);
 if result->>'status'<>'approved' or (result->>'version')::integer<>5 then raise exception 'Approval result mismatch';end if;
 perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,'66117788-0000-4000-8000-000000000033',4,1,'Approved following the business process.','Eligibility file reference A1',true,true);
 if (select count(*) from public.rental_approval_decisions)<>1 or (select count(*) from public.rental_unit_reservations where state='held')<>1 or not exists(select 1 from public.rental_approval_decisions where jsonb_array_length(document_snapshot)=1 and jsonb_array_length(cosigner_snapshot)=1) then raise exception 'Approval retry or frozen evidence mismatch';end if;
 begin update public.rental_unit_reservations set state='released';raise exception 'Staff bypassed reservation';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000020',true);
select set_config('openhouse.test_template',public.register_approved_lease_template(gen_random_uuid(),'residential',0,'Residential lease fixture','Business approved source fixture',repeat('a',64),true)->>'id',true);
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000003',true);
select set_config('openhouse.test_lease_request',gen_random_uuid()::text,true);
select set_config('openhouse.test_lease',public.prepare_rental_lease_draft(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease_request')::uuid,5,0,current_setting('openhouse.test_template')::uuid,1,(now() at time zone 'America/Jamaica')::date+30,(now() at time zone 'America/Jamaica')::date+395,31,10000010,'Approved draft terms fixture',true)->>'id',true);
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000003',true);
set local role authenticated;
select set_config('openhouse.sign_request',gen_random_uuid()::text,true);
select set_config('openhouse.sign_receipt',public.request_rental_lease_signing(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,current_setting('openhouse.sign_request')::uuid,'Business-approved signing intent',true)::text,true);
do $$ declare r jsonb;begin
 r:=public.request_rental_lease_signing(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,current_setting('openhouse.sign_request')::uuid,'Business-approved signing intent',true);
 if r<>current_setting('openhouse.sign_receipt')::jsonb or r->>'state'<>'awaiting_provider' or (select count(*) from public.rental_lease_signing_requests)<>1 then raise exception 'Replay or pending state failed';end if;
 begin perform public.request_rental_lease_signing(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,current_setting('openhouse.sign_request')::uuid,'Changed signing intent',true);raise exception 'Changed replay accepted';exception when invalid_parameter_value then null;end;
 begin perform public.request_rental_lease_signing(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,2,gen_random_uuid(),'Stale signing intent',true);raise exception 'Stale draft accepted';exception when serialization_failure then null;end;
 begin perform public.request_rental_lease_signing(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,gen_random_uuid(),'Unapproved signing intent',false);raise exception 'Missing approval accepted';exception when invalid_parameter_value then null;end;
 begin update public.rental_lease_signing_requests set approval_reference='Changed';raise exception 'Direct edit accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000001',true);
do $$ begin
 if exists(select 1 from public.rental_lease_signing_requests) then raise exception 'Applicant read internal request';end if;
 begin perform public.request_rental_lease_signing(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,gen_random_uuid(),'Self signing intent',true);raise exception 'Self approval accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.rental_lease_signing_requests) then raise exception 'Foreign organization read intent';end if;
 begin perform public.request_rental_lease_signing(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,gen_random_uuid(),'Foreign signing attempt',true);raise exception 'Foreign organization wrote intent';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000005',true);
do $$ begin
 begin perform public.request_rental_lease_signing(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,gen_random_uuid(),'Unverified signing attempt',true);raise exception 'Unverified user wrote intent';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000020',true);
select public.manage_staff_membership(gen_random_uuid(),'reviewer@example.invalid',null,(select membership_revision from public.staff_accounts where user_id='66117788-0000-4000-8000-000000000003'),'Remove signing authority fixture',true);
select set_config('request.jwt.claim.sub','66117788-0000-4000-8000-000000000003',true);
do $$ begin
 if exists(select 1 from public.rental_lease_signing_requests) then raise exception 'Revoked user read intent';end if;
 begin perform public.request_rental_lease_signing(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,current_setting('openhouse.sign_request')::uuid,'Business-approved signing intent',true);raise exception 'Revoked user replayed intent';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 begin update public.rental_lease_signing_requests set approval_reference='Modified history';raise exception 'Owner changed immutable intent';exception when unique_violation then null;end;
 begin delete from public.rental_lease_signing_requests;raise exception 'Owner deleted immutable intent';exception when unique_violation then null;end;
 if has_table_privilege('service_role','public.rental_lease_signing_requests','INSERT') or has_function_privilege('anon','public.request_rental_lease_signing(uuid,uuid,integer,uuid,text,boolean)','EXECUTE') then raise exception 'Privileged bypass grants open';end if;
end $$;
rollback;
select 'PASS: signing pending state/replay/approval/revision, independent applicant and foreign-org isolation, unverified/revoked authority, owner immutability and explicit grants; fixtures rolled back' as verification;
