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
insert into auth.users(id,email,email_confirmed_at) values('55667788-0000-4000-8000-000000000020','administrator@example.invalid',now());
insert into public.staff_accounts(user_id,organization_id,role) values('55667788-0000-4000-8000-000000000020','55667788-0000-4000-8000-000000000006','admin');
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000020',true);
set local role authenticated;
select set_config('openhouse.test_template',public.register_approved_lease_template('55667788-0000-4000-8000-000000000030','residential',0,'Residential fixture template','Approved source fixture reference',repeat('a',64),true)->>'id',true);
do $$ begin
 perform public.register_approved_lease_template('55667788-0000-4000-8000-000000000030','residential',0,'Residential fixture template','Approved source fixture reference',repeat('a',64),true);
 if (select count(*) from public.approved_lease_templates)<>1 then raise exception 'Template retry duplicated';end if;
 begin perform public.register_approved_lease_template(gen_random_uuid(),'residential',0,'Stale template','Approved source fixture reference',repeat('a',64),true);raise exception 'Stale template overwrite accepted';exception when serialization_failure then null;end;
 begin perform public.register_approved_lease_template(gen_random_uuid(),'residential',1,'Unapproved template','Approved source fixture reference',repeat('a',64),false);raise exception 'Missing business approval accepted';exception when invalid_parameter_value then null;end;
 begin update public.approved_lease_templates set title='Changed immutable version';raise exception 'Direct template mutation allowed';exception when insufficient_privilege then null;end;
 perform public.register_approved_lease_template(gen_random_uuid(),'residential',1,'Residential revised fixture','New approved source fixture reference',repeat('b',64),true);
 if (select count(*) from public.approved_lease_templates)<>2 or not exists(select 1 from public.approved_lease_templates where id=current_setting('openhouse.test_template')::uuid and version=1 and content_sha256=repeat('a',64)) then raise exception 'Prior approved template altered';end if;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ begin
 if (select count(*) from public.approved_lease_templates)<>2 then raise exception 'Verified staff cannot read organization templates';end if;
 begin perform public.register_approved_lease_template(gen_random_uuid(),'residential',2,'Manager alteration','Approved source fixture reference',repeat('c',64),true);raise exception 'Manager registered template';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin if exists(select 1 from public.approved_lease_templates) then raise exception 'Foreign template disclosure';end if;end $$;
select public.register_approved_lease_template(gen_random_uuid(),'residential',0,'Foreign own template','Foreign approved source reference',repeat('c',64),true);
do $$ begin if (select count(*) from public.approved_lease_templates)<>1 or exists(select 1 from public.approved_lease_templates where id=current_setting('openhouse.test_template')::uuid) then raise exception 'Cross-organization key collision/disclosure';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin
 if exists(select 1 from public.approved_lease_templates) then raise exception 'Unverified staff template disclosure';end if;
 begin perform public.register_approved_lease_template(gen_random_uuid(),'residential',2,'Unverified alteration','Approved source fixture reference',repeat('c',64),true);raise exception 'Unverified staff registered template';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.approved_lease_templates) then raise exception 'Prospect internal template disclosure';end if;end $$;
reset role;
do $$ begin
 begin update public.approved_lease_templates set content_sha256=repeat('d',64) where id=current_setting('openhouse.test_template')::uuid;raise exception 'Template fingerprint mutable';exception when unique_violation then null;end;
 begin delete from public.approved_lease_templates where id=current_setting('openhouse.test_template')::uuid;raise exception 'Template history removable';exception when unique_violation then null;end;
 if has_table_privilege('service_role','public.approved_lease_templates','INSERT') then raise exception 'Direct service template insertion open';end if;
 begin insert into public.approved_lease_templates(organization_id,template_key,version,title,source_reference,content_sha256,approved_by,request_id) values('55667788-0000-4000-8000-000000000006','invalid_approver',1,'Fixture title','Fixture approved reference',repeat('a',64),'55667788-0000-4000-8000-000000000003',gen_random_uuid());raise exception 'Manager-bound approval accepted';exception when insufficient_privilege then null;end;
end $$;
-- Storage metadata only; this fixture does not prove actual PDF byte verification.
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000020',true);
set local role authenticated;
select set_config('openhouse.legal_doc',public.reserve_lease_template_document(current_setting('openhouse.test_template')::uuid,'55667788-0000-4000-8000-000000000041','approved.pdf',100)::text,true);
do $$ declare d jsonb:=current_setting('openhouse.legal_doc')::jsonb; begin
 if public.reserve_lease_template_document(current_setting('openhouse.test_template')::uuid,'55667788-0000-4000-8000-000000000041','approved.pdf',100)<>d then raise exception 'Reservation retry changed';end if;
 begin perform public.reserve_lease_template_document(current_setting('openhouse.test_template')::uuid,gen_random_uuid(),'duplicate.pdf',100);raise exception 'Competing reservation accepted';exception when unique_violation then null;end;
 insert into storage.objects(bucket_id,name) values('lease-template-documents',d->>'path');
 begin perform public.finish_lease_template_document(auth.uid(),(d->>'id')::uuid,100,repeat('a',64));raise exception 'Client certified PDF';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role service_role;
do $$ declare d jsonb:=current_setting('openhouse.legal_doc')::jsonb; begin
 begin perform public.finish_lease_template_document('55667788-0000-4000-8000-000000000020',(d->>'id')::uuid,100,repeat('b',64));raise exception 'Wrong fingerprint certified';exception when invalid_parameter_value then null;end;
 perform public.finish_lease_template_document('55667788-0000-4000-8000-000000000020',(d->>'id')::uuid,100,repeat('a',64));
 perform public.finish_lease_template_document('55667788-0000-4000-8000-000000000020',(d->>'id')::uuid,100,repeat('a',64));
end $$;
reset role;
set local role authenticated;
do $$ begin
 begin perform public.withdraw_lease_template_document((current_setting('openhouse.legal_doc')::jsonb->>'id')::uuid);raise exception 'Certified PDF withdrawn';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ begin
 if (select count(*) from storage.objects where bucket_id='lease-template-documents')<>1 then raise exception 'Manager cannot read certified PDF';end if;
 begin perform public.reserve_lease_template_document(current_setting('openhouse.test_template')::uuid,gen_random_uuid(),'manager.pdf',100);raise exception 'Manager reserved PDF';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin if exists(select 1 from storage.objects where bucket_id='lease-template-documents') then raise exception 'Foreign PDF disclosure';end if;end $$;
reset role;
do $$ begin if (select count(*) from public.lease_template_document_events)<>2 then raise exception 'Certification retry duplicated audit';end if;end $$;

-- Isolated Storage metadata fixture: no real PDF uploads or deletions.
insert into public.lease_template_documents(id,template_id,organization_id,user_id,request_id,file_name,declared_size,object_path,expected_sha256,expires_at)
select ('55667788-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,current_setting('openhouse.test_template')::uuid,'55667788-0000-4000-8000-000000000006','55667788-0000-4000-8000-000000000020',gen_random_uuid(),'expired.pdf',100,'fixture/cleanup/'||i||'.pdf',repeat('a',64),now()-case when i=61 then interval '1 hour' else interval '3 hours' end from generate_series(60,62)i;
update public.lease_template_documents set state='withdrawn',withdrawn_at=now() where id='55667788-0000-4000-8000-000000000062';
insert into storage.objects(bucket_id,name) values('lease-template-documents','fixture/cleanup/62.pdf');
set local role authenticated;
do $$ begin
 begin perform public.claim_expired_lease_template_document();raise exception 'Client cleanup allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role service_role;
select set_config('openhouse.legal_claims',(select jsonb_agg(to_jsonb(c))::text from public.claim_expired_lease_template_document()c),true);
do $$ declare claims jsonb:=current_setting('openhouse.legal_claims')::jsonb;nonce uuid;begin
 if jsonb_array_length(claims)<>2 then raise exception 'Cleanup eligibility incorrect';end if;
 if exists(select 1 from jsonb_array_elements(claims)c where c->>'id' not in('55667788-0000-4000-8000-000000000060','55667788-0000-4000-8000-000000000062')) then raise exception 'Grace or certified PDF claimed';end if;
 if exists(select 1 from public.claim_expired_lease_template_document()) then raise exception 'Active claim reused';end if;
 select (c->>'claim_id')::uuid into nonce from jsonb_array_elements(claims)c where c->>'id'='55667788-0000-4000-8000-000000000060';
 perform public.mark_lease_template_document_purged('55667788-0000-4000-8000-000000000060',nonce);
 perform public.mark_lease_template_document_purged('55667788-0000-4000-8000-000000000060',nonce);
 select (c->>'claim_id')::uuid into nonce from jsonb_array_elements(claims)c where c->>'id'='55667788-0000-4000-8000-000000000062';
 perform set_config('openhouse.old_legal_claim',nonce::text,true);
 begin perform public.mark_lease_template_document_purged('55667788-0000-4000-8000-000000000062',nonce);raise exception 'Existing Storage object marked purged';exception when unique_violation then null;end;
 begin perform public.mark_lease_template_document_purged('55667788-0000-4000-8000-000000000062',gen_random_uuid());raise exception 'Wrong claim accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.lease_template_document_events where document_id='55667788-0000-4000-8000-000000000060' and event_name='expired')<>1 then raise exception 'Expiry audit missing';end if;
 if exists(select 1 from public.lease_template_documents where state='certified' and purged_at is not null) then raise exception 'Certified PDF purged';end if;
end $$;
update private.lease_template_document_cleanup_claims set claimed_at=now()-interval '6 minutes' where document_id='55667788-0000-4000-8000-000000000062';
set local role service_role;
do $$ begin
 begin perform public.mark_lease_template_document_purged('55667788-0000-4000-8000-000000000062',current_setting('openhouse.old_legal_claim')::uuid);raise exception 'Expired claim accepted';exception when unique_violation then null;end;
end $$;
select public.claim_expired_lease_template_document();
do $$ begin
 begin perform public.mark_lease_template_document_purged('55667788-0000-4000-8000-000000000062',current_setting('openhouse.old_legal_claim')::uuid);raise exception 'Replaced claim accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;

insert into public.lease_template_documents(template_id,organization_id,user_id,request_id,file_name,declared_size,object_path,expected_sha256,expires_at)
select current_setting('openhouse.test_template')::uuid,'55667788-0000-4000-8000-000000000006','55667788-0000-4000-8000-000000000020',gen_random_uuid(),'batch.pdf',100,'fixture/legal-batch/'||gen_random_uuid()::text||'.pdf',repeat('a',64),now()-interval '3 hours' from generate_series(1,25);
set local role service_role;
do $$ begin
 if (select count(*) from public.claim_expired_lease_template_document())<>20 then raise exception 'Cleanup batch cap failed';end if;
 if (select count(*) from public.claim_expired_lease_template_document())<>5 then raise exception 'Cleanup remaining batch failed';end if;
 if exists(select 1 from public.claim_expired_lease_template_document()) then raise exception 'Active batch claims reused';end if;
end $$;
reset role;
rollback;
