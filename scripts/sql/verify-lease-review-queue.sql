begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('88330011-0000-4000-8000-000000000001','applicant@example.invalid',now()),
 ('88330011-0000-4000-8000-000000000002','other@example.invalid',now()),
 ('88330011-0000-4000-8000-000000000003','reviewer@example.invalid',now()),
 ('88330011-0000-4000-8000-000000000004','foreign@example.invalid',now()),
 ('88330011-0000-4000-8000-000000000005','unverified@example.invalid',null);
insert into public.organizations(id,name) values ('88330011-0000-4000-8000-000000000006','Application fixtures'),('88330011-0000-4000-8000-000000000007','Foreign application fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
 ('88330011-0000-4000-8000-000000000003','88330011-0000-4000-8000-000000000006','manager'),
 ('88330011-0000-4000-8000-000000000004','88330011-0000-4000-8000-000000000007','admin'),
 ('88330011-0000-4000-8000-000000000005','88330011-0000-4000-8000-000000000006','realtor'),
 ('88330011-0000-4000-8000-000000000001','88330011-0000-4000-8000-000000000006','realtor');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values
 ('88330011-0000-4000-8000-000000000008','88330011-0000-4000-8000-000000000006','Rental fixture','Kingston','rent','house','published',100000,'Approved rental fixture description.','https://example.invalid/approved.jpg'),
 ('88330011-0000-4000-8000-000000000009','88330011-0000-4000-8000-000000000006','Sale fixture','Kingston','sale','house','published',10000000,'Approved sale fixture description.','https://example.invalid/approved.jpg'),
 ('88330011-0000-4000-8000-000000000010','88330011-0000-4000-8000-000000000006','Draft rental fixture','Kingston','rent','house','draft',100000,'','');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url)
select ('88330011-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'88330011-0000-4000-8000-000000000006','Additional rental '||i,'Kingston','rent','house','published',100000,'Approved additional rental description.','https://example.invalid/approved.jpg' from generate_series(51,53) i;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.test_application',public.submit_rental_application('88330011-0000-4000-8000-000000000012','88330011-0000-4000-8000-000000000008',null,'Test Applicant','',2,(now() at time zone 'America/Jamaica')::date+30,'Please review my rental application.',true)::text,true);
select set_config('openhouse.test_document',public.reserve_application_document(current_setting('openhouse.test_application')::uuid,'88330011-0000-4000-8000-000000000013','identity','identity.pdf','application/pdf',20)::text,true);
do $$ declare doc jsonb:=current_setting('openhouse.test_document')::jsonb;retry jsonb;begin
 retry:=public.reserve_application_document(current_setting('openhouse.test_application')::uuid,'88330011-0000-4000-8000-000000000013','identity','identity.pdf','application/pdf',20);
 if doc<>retry then raise exception 'Reservation retry differs';end if;
 if not private.application_document_storage_access(doc->>'path','insert') then raise exception 'Owner cannot upload reserved path';end if;
 begin perform public.finish_application_document(auth.uid(),(doc->>'id')::uuid,20,'application/pdf',repeat('a',64));raise exception 'Applicant certified file';exception when insufficient_privilege then null;end;
 begin update public.application_documents set state='uploaded';raise exception 'Applicant updated metadata';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
do $$ begin if exists(select 1 from public.application_documents) or private.application_document_storage_access(current_setting('openhouse.test_document')::jsonb->>'path','read') then raise exception 'Staff saw unfinished file';end if;end $$;
reset role;
set local role service_role;
select public.finish_application_document('88330011-0000-4000-8000-000000000001',(current_setting('openhouse.test_document')::jsonb->>'id')::uuid,20,'application/pdf',repeat('a',64));
select public.finish_application_document('88330011-0000-4000-8000-000000000001',(current_setting('openhouse.test_document')::jsonb->>'id')::uuid,20,'application/pdf',repeat('a',64));
reset role;
set local role authenticated;
select public.transition_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),1,'start_review','Reviewing evidence before approval.');
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),2,1,'Approved following the business process.','Eligibility file reference A1',true,true);raise exception 'Unconfigured policy approval';exception when invalid_parameter_value then null;end;
end $$;
reset role;
insert into auth.users(id,email,email_confirmed_at) values('88330011-0000-4000-8000-000000000020','admin@example.invalid',now());
insert into public.staff_accounts(user_id,organization_id,role) values('88330011-0000-4000-8000-000000000020','88330011-0000-4000-8000-000000000006','admin');
insert into public.properties(id,organization_id,name,area,address_text) values('88330011-0000-4000-8000-000000000030','88330011-0000-4000-8000-000000000006','Managed fixture','Kingston','Private fixture address');
insert into public.units(id,property_id,unit_label) values('88330011-0000-4000-8000-000000000031','88330011-0000-4000-8000-000000000030','Unit A');
update public.listings set property_id='88330011-0000-4000-8000-000000000030',unit_id='88330011-0000-4000-8000-000000000031' where id in('88330011-0000-4000-8000-000000000008','88330011-0000-4000-8000-000000000051');
set local role authenticated;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000020',true);
select public.configure_rental_approval_policy('88330011-0000-4000-8000-000000000032',0,array['identity'],1,array['manager'],'Approved business fixture policy A',true);
select public.configure_rental_approval_policy('88330011-0000-4000-8000-000000000032',0,array['identity'],1,array['manager'],'Approved business fixture policy A',true);
do $$ begin
 if (select count(*) from public.rental_approval_policies)<>1 then raise exception 'Policy retry duplicated';end if;
 begin perform public.configure_rental_approval_policy(gen_random_uuid(),0,array['identity'],1,array['manager'],'Changed policy reference',true);raise exception 'Stale policy accepted';exception when serialization_failure then null;end;
 begin perform public.configure_rental_approval_policy(gen_random_uuid(),1,array['identity'],1,array['manager'],'Unapproved policy reference',false);raise exception 'Unapproved policy accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.configure_rental_approval_policy(gen_random_uuid(),1,array['identity'],1,array['manager'],'Manager policy edit attempt',true);raise exception 'Manager configured policy';exception when insufficient_privilege then null;end;
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),2,1,'Approved following the business process.','Eligibility file reference A1',true,true);raise exception 'Unverified documents approved';exception when invalid_parameter_value then null;end;
end $$;
select public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,gen_random_uuid(),0,'verified','Identity source confirmed for fixture.');
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),2,1,'Approved following the business process.','Eligibility file reference A1',true,true);raise exception 'Missing cosigner approved';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000001',true);
select set_config('openhouse.test_cosigner',public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'other@example.invalid',true)::text,true);
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000002',true);
select public.respond_application_cosigner(current_setting('openhouse.test_cosigner')::uuid,gen_random_uuid(),1,'accept',true);
reset role;
insert into public.staff_accounts(user_id,organization_id,role) values('88330011-0000-4000-8000-000000000002','88330011-0000-4000-8000-000000000006','manager');
set local role authenticated;
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Co-signer staff approval attempted.','Co-signer evidence reference',true,true);raise exception 'Participating co-signer approved own involvement';exception when insufficient_privilege then null;end;
end $$;
reset role;
delete from public.staff_accounts where user_id='88330011-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.rental_approval_policies) then raise exception 'Foreign policy disclosure';end if;
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Foreign staff approval attempted.','Foreign eligibility reference',true,true);raise exception 'Foreign approval accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000001',true);
do $$ begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Applicant self approval attempted.','Applicant eligibility reference',true,true);raise exception 'Self approval accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000002',true);
select set_config('openhouse.test_competing',public.submit_rental_application(gen_random_uuid(),'88330011-0000-4000-8000-000000000051',null,'Competing Applicant','',2,(now() at time zone 'America/Jamaica')::date+30,'Please review the other listing of this unit.',true)::text,true);
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
reset role;
do $$ begin
 update public.listings set price_jmd=110000 where id='88330011-0000-4000-8000-000000000008';
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Approval with changed terms.','Eligibility source A1',true,true);raise exception 'Changed rent terms approved';exception when invalid_parameter_value then null;end;
 update public.listings set price_jmd=100000,unit_id=null where id='88330011-0000-4000-8000-000000000008';
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Approval without a managed unit.','Eligibility source A1',true,true);raise exception 'Unbound listing approved';exception when invalid_parameter_value then null;end;
 update public.listings set unit_id='88330011-0000-4000-8000-000000000031' where id='88330011-0000-4000-8000-000000000008';
end $$;
set local role authenticated;
do $$ declare result jsonb;begin
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,'Incomplete checks approval attempt.','Eligibility file reference A1',false,true);raise exception 'Missing eligibility check approved';exception when invalid_parameter_value then null;end;
 begin perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),3,1,'Stale approval attempted.','Eligibility file reference A1',true,true);raise exception 'Stale application approved';exception when serialization_failure then null;end;
 result:=public.approve_rental_application(current_setting('openhouse.test_application')::uuid,'88330011-0000-4000-8000-000000000033',4,1,'Approved following the business process.','Eligibility file reference A1',true,true);
 if result->>'status'<>'approved' or (result->>'version')::integer<>5 then raise exception 'Approval result mismatch';end if;
 perform public.approve_rental_application(current_setting('openhouse.test_application')::uuid,'88330011-0000-4000-8000-000000000033',4,1,'Approved following the business process.','Eligibility file reference A1',true,true);
 if (select count(*) from public.rental_approval_decisions)<>1 or (select count(*) from public.rental_unit_reservations where state='held')<>1 or not exists(select 1 from public.rental_approval_decisions where jsonb_array_length(document_snapshot)=1 and jsonb_array_length(cosigner_snapshot)=1) then raise exception 'Approval retry or frozen evidence mismatch';end if;
 begin update public.rental_unit_reservations set state='released';raise exception 'Staff bypassed reservation';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000020',true);
select set_config('openhouse.test_template',public.register_approved_lease_template(gen_random_uuid(),'residential',0,'Residential lease fixture','Business approved source fixture',repeat('a',64),true)->>'id',true);
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
select set_config('openhouse.test_lease_request',gen_random_uuid()::text,true);
select set_config('openhouse.test_lease',public.prepare_rental_lease_draft(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease_request')::uuid,5,0,current_setting('openhouse.test_template')::uuid,1,(now() at time zone 'America/Jamaica')::date+30,(now() at time zone 'America/Jamaica')::date+395,31,10000010,'Approved draft terms fixture',true)->>'id',true);
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000001',true);
do $$ begin
 if public.applicant_lease_summaries(current_setting('openhouse.test_application')::uuid,1)->>'total'<>'0' then raise exception 'Unreleased draft exposed';end if;
 begin perform public.release_rental_lease_summary(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,gen_random_uuid(),'Self release denied',true);raise exception 'Applicant released own summary';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
select set_config('openhouse.release_request',gen_random_uuid()::text,true);
select set_config('openhouse.release',public.release_rental_lease_summary(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,current_setting('openhouse.release_request')::uuid,'Internal summary sharing approval',true)->>'id',true);
do $$ declare result jsonb;begin
 result:=public.release_rental_lease_summary(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,current_setting('openhouse.release_request')::uuid,'Internal summary sharing approval',true);
 if result->>'id'<>current_setting('openhouse.release') or (select count(*) from public.rental_lease_summary_releases)<>1 then raise exception 'Release retry duplicated';end if;
 begin perform public.release_rental_lease_summary(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,current_setting('openhouse.release_request')::uuid,'Changed sharing approval',true);raise exception 'Changed release retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.release_rental_lease_summary(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,gen_random_uuid(),'Second release denied',true);raise exception 'Duplicate release accepted';exception when unique_violation then null;end;
 begin perform public.applicant_lease_summaries(current_setting('openhouse.test_application')::uuid,1);raise exception 'Staff read applicant projection';exception when insufficient_privilege then null;end;
 begin update public.rental_lease_summary_releases set release_reference='Changed';raise exception 'Staff mutated release';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000001',true);
do $$ declare result jsonb;item jsonb;begin
 result:=public.applicant_lease_summaries(current_setting('openhouse.test_application')::uuid,1);item:=result->'items'->0;
 if result->>'total'<>'1' or item->>'rent_minor'<>'10000000' or item->>'deposit_minor'<>'10000010' or item->>'state'<>'prepared' or item->>'version'<>'1' then raise exception 'Released summary terms mismatch';end if;
 if item ?| array['snapshot','terms_reference','release_reference','cosigners','prepared_by','source_reference','closed_reason','property_address'] then raise exception 'Internal release fields disclosed';end if;
 if exists(select 1 from public.rental_lease_summary_releases) then raise exception 'Applicant read internal release records';end if;
 if public.applicant_lease_summaries(current_setting('openhouse.test_application')::uuid,2)->>'total'<>'1' or jsonb_array_length(public.applicant_lease_summaries(current_setting('openhouse.test_application')::uuid,2)->'items')<>0 then raise exception 'Projection page scope failed';end if;
 begin perform public.applicant_lease_summaries(current_setting('openhouse.test_application')::uuid,0);raise exception 'Invalid projection page accepted';exception when invalid_parameter_value then null;end;
end $$;
do $$ declare caller text;begin
 foreach caller in array array['88330011-0000-4000-8000-000000000002','88330011-0000-4000-8000-000000000004','88330011-0000-4000-8000-000000000005'] loop
 perform set_config('request.jwt.claim.sub',caller,true);
 begin perform public.applicant_lease_summaries(current_setting('openhouse.test_application')::uuid,1);raise exception 'Foreign/co-signer/unverified projection disclosure';exception when insufficient_privilege then null;end;
 begin perform public.release_rental_lease_summary(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1,gen_random_uuid(),'Unauthorized release attempt',true);raise exception 'Unauthorized release accepted';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
do $$ declare result jsonb;begin
 result:=public.prepare_rental_lease_draft(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease_request')::uuid,5,0,current_setting('openhouse.test_template')::uuid,1,(now() at time zone 'America/Jamaica')::date+30,(now() at time zone 'America/Jamaica')::date+395,31,10000010,'Approved draft terms fixture',true);
 if result->>'id'<>current_setting('openhouse.test_lease') or (select count(*) from public.rental_lease_drafts)<>1 then raise exception 'Draft retry duplicated';end if;
 if not exists(select 1 from public.rental_lease_drafts where rent_minor=10000000 and deposit_minor=10000010 and snapshot->'applicant'->>'email'='applicant@example.invalid' and jsonb_array_length(snapshot->'cosigners')=1 and snapshot->'unit'->>'label'='Unit A') then raise exception 'Derived frozen draft terms missing';end if;
 if (select status from public.rental_applications where id=current_setting('openhouse.test_application')::uuid)<>'approved' then raise exception 'Draft activated application';end if;
 begin perform public.prepare_rental_lease_draft(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),4,1,current_setting('openhouse.test_template')::uuid,1,(now() at time zone 'America/Jamaica')::date+30,(now() at time zone 'America/Jamaica')::date+395,1,0,'Stale application terms fixture',true);raise exception 'Stale application drafted';exception when serialization_failure then null;end;
 begin perform public.prepare_rental_lease_draft(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),5,0,current_setting('openhouse.test_template')::uuid,1,(now() at time zone 'America/Jamaica')::date+30,(now() at time zone 'America/Jamaica')::date+395,1,0,'Stale draft terms fixture',true);raise exception 'Stale draft replaced';exception when serialization_failure then null;end;
 begin perform public.prepare_rental_lease_draft(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),5,1,current_setting('openhouse.test_template')::uuid,1,(now() at time zone 'America/Jamaica')::date-1,(now() at time zone 'America/Jamaica')::date+395,1,0,'Past lease terms fixture',true);raise exception 'Past lease prepared';exception when invalid_parameter_value then null;end;
 begin perform public.prepare_rental_lease_draft(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease_request')::uuid,5,0,current_setting('openhouse.test_template')::uuid,1,(now() at time zone 'America/Jamaica')::date+30,(now() at time zone 'America/Jamaica')::date+395,1,10000010,'Approved draft terms fixture',true);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin update public.rental_lease_drafts set state='voided';raise exception 'Staff bypassed immutable draft';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 begin update public.rental_lease_drafts set rent_minor=rent_minor+1 where id=current_setting('openhouse.test_lease')::uuid;raise exception 'Approved rent mutable';exception when unique_violation then null;end;
 begin update public.rental_lease_drafts set snapshot=snapshot||'{"fake_signed":true}'::jsonb where id=current_setting('openhouse.test_lease')::uuid;raise exception 'Participant snapshot mutable';exception when unique_violation then null;end;
 begin delete from public.rental_lease_drafts where id=current_setting('openhouse.test_lease')::uuid;raise exception 'Lease preparation removable';exception when unique_violation then null;end;
 begin update public.rental_lease_drafts set state='voided',closed_at=now(),closed_reason='' where id=current_setting('openhouse.test_lease')::uuid;raise exception 'Unexplained closure allowed';exception when unique_violation then null;end;
 if has_table_privilege('service_role','public.rental_lease_drafts','INSERT') or has_table_privilege('service_role','public.rental_lease_drafts','UPDATE') then raise exception 'Direct service draft writes open';end if;
end $$;
set local role service_role;
do $$ begin
 begin update public.rental_lease_drafts set deposit_minor=0;raise exception 'Service rewrote approved deposit';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000020',true);
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),0,'answer','A reply without a question.',true);raise exception 'Question-free reply accepted';exception when unique_violation then null;end;
 begin perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),0,'reviewed','',true);raise exception 'Staff impersonated applicant review';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000001',true);
select set_config('openhouse.review',public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,'88330011-0000-4000-8000-000000000901',0,'reviewed','',true)->>'id',true);
do $$ declare result jsonb;begin
 result:=public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,'88330011-0000-4000-8000-000000000901',0,'reviewed','',true);
 if result->>'id'<>current_setting('openhouse.review') or (select count(id) from public.rental_lease_review_events)<>1 then raise exception 'Review retry duplicated';end if;
 begin perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,'88330011-0000-4000-8000-000000000901',0,'question','Changed request payload.',true);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),0,'question','A stale review response.',true);raise exception 'Stale review accepted';exception when serialization_failure then null;end;
 begin perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),1,'answer','Applicant reply impersonation.',true);raise exception 'Applicant answered as staff';exception when insufficient_privilege then null;end;
 begin perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),1,'question','No review acknowledgment.',false);raise exception 'Unacknowledged review accepted';exception when invalid_parameter_value then null;end;
 begin perform (select actor_user_id from public.rental_lease_review_events limit 1);raise exception 'Private actor identity exposed';exception when insufficient_privilege then null;end;
end $$;
select public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,'88330011-0000-4000-8000-000000000902',1,'question','Please clarify the shorter-month billing schedule.',true);
do $$ begin
 begin perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),2,'reviewed','',true);raise exception 'Pending question silently cleared';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
do $$ begin if (select count(*) from public.pending_lease_review_questions)<>1 or not exists(select 1 from public.pending_lease_review_questions where review_version=2 and draft_version=1 and message='Please clarify the shorter-month billing schedule.') then raise exception 'Pending question queue mismatch';end if;end $$;
select public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,'88330011-0000-4000-8000-000000000903',2,'answer','The approved schedule will be shown in the full legal lease.',true);
select public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,'88330011-0000-4000-8000-000000000903',2,'answer','The approved schedule will be shown in the full legal lease.',true);
do $$ declare result jsonb;begin
 result:=public.lease_summary_review_history(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1);
 if exists(select 1 from public.pending_lease_review_questions) then raise exception 'Answered question remained pending';end if;
 if result->>'role'<>'staff' or result->>'revision'<>'3' or result->>'total'<>'3' or result->>'current'<>'true' or result->'items'->0->>'action'<>'answer' then raise exception 'Staff review history mismatch';end if;
 if result->'items'->0 ?| array['actor_user_id','request_id','release_reference','snapshot'] then raise exception 'Private history fields leaked';end if;
 begin update public.rental_lease_review_events set message='Changed shared response';raise exception 'Direct review update accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000001',true);
do $$ declare result jsonb;begin
 result:=public.lease_summary_review_history(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1);
 if result->>'role'<>'applicant' or result->>'latest_action'<>'answer' or jsonb_array_length(result->'items')<>3 or result->'summary'->>'rent_minor'<>'10000000' then raise exception 'Applicant review history mismatch';end if;
 if jsonb_array_length(public.lease_summary_review_history(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,2)->'items')<>0 then raise exception 'History page limit mismatch';end if;
 if (select status from public.rental_applications where id=current_setting('openhouse.test_application')::uuid)<>'approved' then raise exception 'Summary review activated application';end if;
end $$;
do $$ declare caller text;begin
 foreach caller in array array['88330011-0000-4000-8000-000000000002','88330011-0000-4000-8000-000000000004','88330011-0000-4000-8000-000000000005'] loop
 perform set_config('request.jwt.claim.sub',caller,true);
 if exists(select 1 from public.pending_lease_review_questions) then raise exception 'Unauthorized staff queue disclosure';end if;
 if exists(select id from public.rental_lease_review_events) then raise exception 'Foreign/co-signer/unverified shared history disclosure';end if;
 begin perform public.lease_summary_review_history(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1);raise exception 'Unauthorized history projection';exception when insufficient_privilege then null;end;
 begin perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),3,'question','Unauthorized review attempt.',true);raise exception 'Unauthorized review write';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
do $$ declare revision integer:=3;i integer;result jsonb;begin
 for i in 1..12 loop
 perform set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000001',true);
 perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),revision,'question','Clarification question number '||i,true);revision:=revision+1;
 perform set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
 perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),revision,'answer','Shared clarification reply number '||i,true);revision:=revision+1;
 end loop;
 result:=public.lease_summary_review_history(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1);
 if result->>'total'<>'27' or jsonb_array_length(result->'items')<>25 or result->'items'->0->>'version'<>'27' or result->'items'->24->>'version'<>'3' then raise exception 'First history page bound/order failed';end if;
 result:=public.lease_summary_review_history(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,2);
 if jsonb_array_length(result->'items')<>2 or result->'items'->0->>'version'<>'2' or result->'items'->1->>'version'<>'1' then raise exception 'Second history page bound/order failed';end if;
end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000001',true);
select public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),27,'question','Question before replacement.',true);
do $$ begin if exists(select 1 from public.pending_lease_review_questions) then raise exception 'Applicant saw management queue';end if;end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000003',true);
do $$ begin if (select count(*) from public.pending_lease_review_questions)<>1 then raise exception 'New question absent from queue';end if;end $$;
select public.prepare_rental_lease_draft(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),5,1,current_setting('openhouse.test_template')::uuid,1,(now() at time zone 'America/Jamaica')::date+31,(now() at time zone 'America/Jamaica')::date+396,1,0,'Revised approved review fixture terms',true);
do $$ begin if exists(select 1 from public.pending_lease_review_questions) then raise exception 'Replaced question remained in queue';end if;end $$;
select set_config('request.jwt.claim.sub','88330011-0000-4000-8000-000000000001',true);
do $$ begin
 if public.lease_summary_review_history(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1)->>'current'<>'false' then raise exception 'Replaced summary still current';end if;
 if public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,'88330011-0000-4000-8000-000000000901',0,'reviewed','',true)->>'id'<>current_setting('openhouse.review') then raise exception 'Historical retry changed';end if;
 begin perform public.review_rental_lease_summary(current_setting('openhouse.release')::uuid,gen_random_uuid(),28,'question','New question on replaced summary.',true);raise exception 'Historical new response accepted';exception when serialization_failure then null;end;
end $$;
reset role;
update auth.users set email_confirmed_at=null where id='88330011-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
 begin perform public.lease_summary_review_history(current_setting('openhouse.test_application')::uuid,current_setting('openhouse.test_lease')::uuid,1);raise exception 'Unverified owner history disclosure';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 begin delete from public.rental_lease_review_events;raise exception 'Review audit removed';exception when unique_violation then null;end;
 if has_column_privilege('authenticated','public.rental_lease_review_events','actor_user_id','SELECT') or has_table_privilege('service_role','public.rental_lease_review_events','INSERT') or has_function_privilege('anon','public.review_rental_lease_summary(uuid,uuid,integer,text,text,boolean)','EXECUTE') then raise exception 'Review authority exposed';end if;
end $$;
rollback;
select 'PASS: current release review/question/reply, exact retries, revision conflicts, immutable redacted participant history, role/verification isolation and replaced-version guards. Fixtures rolled back; no signing/payment/email.' as verification;
