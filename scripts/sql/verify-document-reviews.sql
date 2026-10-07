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
do $$ begin if (select count(*) from public.application_documents)<>1 or not private.application_document_storage_access(current_setting('openhouse.test_document')::jsonb->>'path','read') then raise exception 'Verified staff missing uploaded file';end if;end $$;
do $$ begin
 begin perform public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,'55667788-0000-4000-8000-000000000014',0,'verified','Checked identity evidence with applicant.');raise exception 'Reviewed submitted application';exception when invalid_parameter_value then null;end;
end $$;
select public.transition_rental_application(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000015',1,'start_review','Reviewing application evidence.');
select public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,'55667788-0000-4000-8000-000000000014',0,'verified','Checked identity evidence with applicant.');
select public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,'55667788-0000-4000-8000-000000000014',0,'verified','Checked identity evidence with applicant.');
do $$ begin
 if (select count(*) from public.application_document_review_events)<>1 or not exists(select 1 from public.application_document_reviews where file_sha256=repeat('a',64) and version=1) then raise exception 'Review snapshot or retry audit failed';end if;
 begin perform public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,'55667788-0000-4000-8000-000000000016',0,'needs_info','Need further source confirmation.');raise exception 'Stale review overwritten';exception when serialization_failure then null;end;
 begin update public.application_document_reviews set status='verified';raise exception 'Staff direct review update allowed';exception when insufficient_privilege then null;end;
end $$;
select public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,'55667788-0000-4000-8000-000000000016',1,'needs_info','Need further source confirmation.');
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
do $$ begin
 if exists(select 1 from public.application_document_reviews) or exists(select 1 from public.application_document_review_events) then raise exception 'Applicant with staff role saw internal verification notes';end if;
 begin perform public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,'55667788-0000-4000-8000-000000000017',2,'verified','Applicant self-verification.');raise exception 'Applicant self-reviewed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.application_document_reviews) or exists(select 1 from public.application_document_review_events) then raise exception 'Foreign staff saw review notes';end if;
 begin perform public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,'55667788-0000-4000-8000-000000000017',2,'verified','Foreign organization verification.');raise exception 'Foreign reviewer accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin
 if exists(select 1 from public.application_document_reviews) then raise exception 'Unverified staff saw review notes';end if;
 begin perform public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,'55667788-0000-4000-8000-000000000017',2,'verified','Unverified account review.');raise exception 'Unverified staff accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
select public.withdraw_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.review_application_document((current_setting('openhouse.test_document')::jsonb->>'id')::uuid,'55667788-0000-4000-8000-000000000017',2,'verified','Withdrawn file review attempt.');raise exception 'Withdrawn document reviewed';exception when invalid_parameter_value then null;end;
 if (select count(*) from public.application_document_review_events)<>2 then raise exception 'Review history mutated';end if;
end $$;
rollback;
