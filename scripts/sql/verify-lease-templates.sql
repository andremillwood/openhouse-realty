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
rollback;
