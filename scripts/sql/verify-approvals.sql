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
select set_config('openhouse.test_application',public.submit_rental_application('55667788-0000-4000-8000-000000000012','55667788-0000-4000-8000-000000000008',null,'Test Applicant','',2,(now() at time zone 'America/Jamaica')::date+30,'Please review my rental application.',true)::text,true);
select set_config('openhouse.test_document',public.reserve_application_document(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000013','identity','identity.pdf','application/pdf',20)::text,true);
do $$ declare doc jsonb:=current_setting('openhouse.test_document')::jsonb;retry jsonb;begin
 retry:=public.reserve_application_document(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000013','identity','identity.pdf','application/pdf',20);
 if doc<>retry then raise exception 'Reservation retry differs';end if;
 if not private.application_document_storage_access(doc->>'path','insert') then raise exception 'Owner cannot upload reserved path';end if;
 begin perform public.finish_application_document(auth.uid(),(doc->>'id')::uuid,20,'application/pdf',repeat('a',64));raise exception 'Applicant certified file';exception when insufficient_privilege then null;end;
 begin update public.application_documents set state='uploaded';raise exception 'Applicant updated metadata';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ begin if exists(select 1 from public.application_documents) or private.application_document_storage_access(current_setting('openhouse.test_document')::jsonb->>'path','read') then raise exception 'Staff saw unfinished file';end if;end $$;
reset role;
set local role service_role;
select public.finish_application_document('55667788-0000-4000-8000-000000000001',(current_setting('openhouse.test_document')::jsonb->>'id')::uuid,20,'application/pdf',repeat('a',64));
select public.finish_application_document('55667788-0000-4000-8000-000000000001',(current_setting('openhouse.test_document')::jsonb->>'id')::uuid,20,'application/pdf',repeat('a',64));
reset role;
set local role authenticated;
select public.transition_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),1,'start_review','Reviewing evidence before approval.');
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),2,1,'Approved following the business process.','Eligibility file reference A1',true,true);raise exception 'Unconfigured policy approval';exception when invalid_parameter_value then null;end;
end $$;
reset role;
insert into auth.users(id,email,email_confirmed_at) values('55667788-0000-4000-8000-000000000020','admin@example.invalid',now());
insert into public.staff_accounts(user_id,organization_id,role) values('55667788-0000-4000-8000-000000000020','55667788-0000-4000-8000-000000000006','admin');
insert into public.properties(id,organization_id,name,area,address_text) values('55667788-0000-4000-8000-000000000030','55667788-0000-4000-8000-000000000006','Managed fixture','Kingston','Private fixture address');
insert into public.units(id,property_id,unit_label) values('55667788-0000-4000-8000-000000000031','55667788-0000-4000-8000-000000000030','Unit A');
update public.listings set property_id='55667788-0000-4000-8000-000000000030',unit_id='55667788-0000-4000-8000-000000000031' where id in('55667788-0000-4000-8000-000000000008','55667788-0000-4000-8000-000000000051');
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000020',true);
select public.configure_rental_approval_policy('55667788-0000-4000-8000-000000000032',0,array['identity'],1,array['manager'],'Approved business fixture policy A',true);
select public.configure_rental_approval_policy('55667788-0000-4000-8000-000000000032',0,array['identity'],1,array['manager'],'Approved business fixture policy A',true);
do $$ begin
 if (select count(*) from public.rental_approval_policies)<>1 then raise exception 'Policy retry duplicated';end if;
 begin perform public.configure_rental_approval_policy(gen_random_uuid(),0,array['identity'],1,array['manager'],'Changed policy reference',true);raise exception 'Stale policy accepted';exception when serialization_failure then null;end;
 begin perform public.configure_rental_approval_policy(gen_random_uuid(),1,array['identity'],1,array['manager'],'Unapproved policy reference',false);raise exception 'Unapproved policy accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.configure_rental_approval_policy(gen_random_uuid(),1,array['identity'],1,array['manager'],'Manager policy edit attempt',true);raise exception 'Manager configured policy';exception when insufficient_privilege then null;end;
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),2,1,'Approved following the business process.','Eligibility file reference A1',true,true);raise exception 'Unverified documents approved';exception when invalid_parameter_value then null;end;
end $$;
select public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,gen_random_uuid(),0,'verified','Identity source confirmed for fixture.');
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),2,1,'Approved following the business process.','Eligibility file reference A1',true,true);raise exception 'Missing cosigner approved';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
select set_config('openhouse.test_cosigner',public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'other@example.invalid',true)::text,true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.respond_application_cosigner(current_setting('openhouse.test_cosigner')::uuid,gen_random_uuid(),1,'accept',true);
reset role;
insert into public.staff_accounts(user_id,organization_id,role) values('55667788-0000-4000-8000-000000000002','55667788-0000-4000-8000-000000000006','manager');
set local role authenticated;
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Co-signer staff approval attempted.','Co-signer evidence reference',true,true);raise exception 'Participating co-signer approved own involvement';exception when insufficient_privilege then null;end;
end $$;
reset role;
delete from public.staff_accounts where user_id='55667788-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.rental_approval_policies) then raise exception 'Foreign policy disclosure';end if;
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Foreign staff approval attempted.','Foreign eligibility reference',true,true);raise exception 'Foreign approval accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Applicant self approval attempted.','Applicant eligibility reference',true,true);raise exception 'Self approval accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select set_config('openhouse.test_competing',public.submit_rental_application(gen_random_uuid(),'55667788-0000-4000-8000-000000000051',null,'Competing Applicant','',2,(now() at time zone 'America/Jamaica')::date+30,'Please review the other listing of this unit.',true)::text,true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
reset role;
do $$ begin
 update public.listings set price_jmd=110000 where id='55667788-0000-4000-8000-000000000008';
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Approval with changed terms.','Eligibility source A1',true,true);raise exception 'Changed rent terms approved';exception when invalid_parameter_value then null;end;
 update public.listings set price_jmd=100000,unit_id=null where id='55667788-0000-4000-8000-000000000008';
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Approval without a managed unit.','Eligibility source A1',true,true);raise exception 'Unbound listing approved';exception when invalid_parameter_value then null;end;
 update public.listings set unit_id='55667788-0000-4000-8000-000000000031' where id='55667788-0000-4000-8000-000000000008';
end $$;
set local role authenticated;
do $$ declare result jsonb;begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Incomplete checks approval attempt.','Eligibility file reference A1',false,true);raise exception 'Missing eligibility check approved';exception when invalid_parameter_value then null;end;
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),3,1,'Stale approval attempted.','Eligibility file reference A1',true,true);raise exception 'Stale application approved';exception when serialization_failure then null;end;
 result:=public.approve_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000033',4,1,'Approved following the business process.','Eligibility file reference A1',true,true);
 if result->>'status'<>'approved' or (result->>'version')::integer<>5 then raise exception 'Approval result mismatch';end if;
 perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000033',4,1,'Approved following the business process.','Eligibility file reference A1',true,true);
 if (select count(*) from public.rental_approval_decisions)<>1 or (select count(*) from public.rental_unit_reservations where state='held')<>1 or not exists(select 1 from public.rental_approval_decisions where jsonb_array_length(document_snapshot)=1 and jsonb_array_length(cosigner_snapshot)=1) then raise exception 'Approval retry or frozen evidence mismatch';end if;
 begin update public.rental_unit_reservations set state='released';raise exception 'Staff bypassed reservation';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 if (select status from public.listings where id='55667788-0000-4000-8000-000000000008')<>'under_offer' or (select count(*) from private.notification_outbox where application_event_id in(select id from public.rental_application_events where application_id=current_setting('openhouse.test_application')::uuid and event_name='approved') and state='pending')<>2 then raise exception 'Listing hold or frozen approval notices missing';end if;
end $$;
do $$ declare decision uuid; violated text;begin
 begin
 insert into public.rental_approval_decisions(application_id,organization_id,policy_id,listing_id,unit_id,approved_by,request_id,application_version,reason,evidence_reference,document_snapshot,cosigner_snapshot) select application_id,organization_id,policy_id,listing_id,unit_id,approved_by,gen_random_uuid(),application_version,reason,evidence_reference,document_snapshot,cosigner_snapshot from public.rental_approval_decisions limit 1 returning id into decision;
 insert into public.rental_unit_reservations(decision_id,application_id,organization_id,listing_id,unit_id) select decision,application_id,organization_id,listing_id,unit_id from public.rental_approval_decisions where id=decision;
 raise exception 'Unique active-unit constraint missing';
 exception when unique_violation then get stacked diagnostics violated=constraint_name;if violated<>'rental_unit_reservations_active_unit' then raise exception 'Wrong conflict constraint %',violated;end if;
 end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000020',true);
select public.configure_rental_approval_policy(gen_random_uuid(),1,array[]::text[],0,array['manager'],'Approved alternate fixture policy B',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);

select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.transition_rental_application(current_setting('openhouse.test_competing')::uuid,gen_random_uuid(),1,'start_review','Reviewing competing unit request.');
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_competing')::uuid,gen_random_uuid(),2,1,'Approved competing unit request.','Eligibility competing reference',true,true);raise exception 'Outdated policy approved';exception when serialization_failure then null;end;
 begin perform public.approve_rental_application(current_setting('openhouse.test_competing')::uuid,gen_random_uuid(),2,2,'Approved competing unit request.','Eligibility competing reference',true,true);raise exception 'Unavailable duplicate listing approved';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000020',true);
do $$ begin
 begin update public.listings set status='published' where id='55667788-0000-4000-8000-000000000051';raise exception 'Reserved duplicate republished';exception when unique_violation then null;end;
 begin perform public.author_managed_inventory(gen_random_uuid(),'listing_link','55667788-0000-4000-8000-000000000008',1,'{"unit_id":null}'::jsonb);raise exception 'Reserved listing unbound';exception when invalid_parameter_value then null;end;
 begin update public.listings set unit_id=null where id='55667788-0000-4000-8000-000000000008';raise exception 'Direct binding bypass allowed';exception when insufficient_privilege then null;end;
 begin perform public.author_managed_inventory(gen_random_uuid(),'property_update','55667788-0000-4000-8000-000000000030',1,'{"name":"Changed reserved property","area":"Kingston","address_text":"Changed exact address"}'::jsonb);raise exception 'Reserved property edited';exception when invalid_parameter_value then null;end;
 begin perform public.author_managed_inventory(gen_random_uuid(),'unit_update','55667788-0000-4000-8000-000000000031',1,'{"unit_label":"Changed reserved unit","bedrooms":2,"bathrooms":1,"parking_spaces":1,"floor":null,"size_sq_ft":1200}'::jsonb);raise exception 'Reserved unit edited';exception when invalid_parameter_value then null;end;
end $$;
update public.listings set price_jmd=0,description='' where id='55667788-0000-4000-8000-000000000008';
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
do $$ begin if exists(select 1 from public.rental_approval_decisions) then raise exception 'Applicant saw internal approval evidence';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.respond_application_cosigner(current_setting('openhouse.test_cosigner')::uuid,gen_random_uuid(),2,'withdraw',false);
reset role;
do $$ begin if (select status from public.rental_applications where id=current_setting('openhouse.test_application')::uuid)<>'under_review' or exists(select 1 from public.rental_unit_reservations where state='held') then raise exception 'Co-signer consent withdrawal did not reopen and release approval';end if;end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
select public.transition_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),6,'withdraw','Applicant withdrew before lease signing.');
reset role;
do $$ begin
 if (select status from public.listings where id='55667788-0000-4000-8000-000000000008')<>'paused' or exists(select 1 from public.rental_unit_reservations where state='held') then raise exception 'Withdrawal did not release safely';end if;
 if exists(select 1 from private.notification_outbox where application_event_id in(select id from public.rental_application_events where application_id=current_setting('openhouse.test_application')::uuid and event_name='approved') and state='pending') then raise exception 'Stale approval notice remained pending';end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000020',true);
update public.listings set status='published' where id='55667788-0000-4000-8000-000000000051';
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.approve_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000033',4,1,'Approved following the business process.','Eligibility file reference A1',true,true);
select public.approve_rental_application(current_setting('openhouse.test_competing')::uuid,gen_random_uuid(),2,2,'Approved competing unit request.','Eligibility competing reference',true,true);
do $$ begin if (select count(*) from public.rental_unit_reservations where state='held')<>1 or (select count(*) from public.rental_approval_decisions)<>2 then raise exception 'Released unit not reusable or old retry reapproved';end if;end $$;
rollback;
