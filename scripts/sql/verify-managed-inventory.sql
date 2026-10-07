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
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select set_config('openhouse.test_property',public.author_managed_inventory('55667788-0000-4000-8000-000000000020','property_create',null,0,'{"name":"Managed home","area":"Kingston","address_text":"Private exact address"}'::jsonb)->>'property_id',true);
do $$ declare property uuid:=current_setting('openhouse.test_property')::uuid;result jsonb;begin
 result:=public.author_managed_inventory('55667788-0000-4000-8000-000000000020','property_create',null,0,'{"name":"Managed home","area":"Kingston","address_text":"Private exact address"}'::jsonb);
 if result->>'property_id'<>property::text or (select count(*) from public.managed_inventory_events)<>1 then raise exception 'Property retry duplicated';end if;
 begin insert into public.properties(organization_id,name) values('55667788-0000-4000-8000-000000000006','Direct bypass');raise exception 'Direct property write allowed';exception when insufficient_privilege then null;end;
 begin perform public.author_managed_inventory(gen_random_uuid(),'property_update',property,1,'{"name":"Spoof home","area":"Kingston","address_text":"Private exact address","organization_id":"spoof"}'::jsonb);raise exception 'Unknown property identity accepted';exception when invalid_parameter_value then null;end;
 perform public.author_managed_inventory(gen_random_uuid(),'property_update',property,1,'{"name":"Managed home updated","area":"Kingston","address_text":"Corrected private address"}'::jsonb);
 begin perform public.author_managed_inventory(gen_random_uuid(),'property_update',property,1,'{"name":"Stale edit","area":"Kingston","address_text":"Private exact address"}'::jsonb);raise exception 'Stale property overwrite allowed';exception when serialization_failure then null;end;
end $$;
select set_config('openhouse.test_unit',public.author_managed_inventory('55667788-0000-4000-8000-000000000021','unit_create',current_setting('openhouse.test_property')::uuid,2,'{"unit_label":"Unit A","bedrooms":2,"bathrooms":1.5,"parking_spaces":1,"floor":null,"size_sq_ft":1200}'::jsonb)->>'unit_id',true);
do $$ declare unit uuid:=current_setting('openhouse.test_unit')::uuid;property uuid:=current_setting('openhouse.test_property')::uuid;begin
 if public.author_managed_inventory('55667788-0000-4000-8000-000000000021','unit_create',property,2,'{"unit_label":"Unit A","bedrooms":2,"bathrooms":1.5,"parking_spaces":1,"floor":null,"size_sq_ft":1200}'::jsonb)->>'unit_id'<>unit::text then raise exception 'Unit retry duplicated';end if;
 begin perform public.author_managed_inventory(gen_random_uuid(),'unit_create',property,2,'{"unit_label":"Unit A","bedrooms":2,"bathrooms":1.5,"parking_spaces":1,"floor":null,"size_sq_ft":1200}'::jsonb);raise exception 'Duplicate unit label allowed';exception when unique_violation then null;end;
 begin perform public.author_managed_inventory(gen_random_uuid(),'unit_update',unit,1,'{"unit_label":"Unit A","bedrooms":2.1,"bathrooms":1.5,"parking_spaces":1,"floor":null,"size_sq_ft":1200}'::jsonb);raise exception 'Fractional unit dimensions accepted';exception when invalid_parameter_value then null;end;
 perform public.author_managed_inventory(gen_random_uuid(),'unit_update',unit,1,'{"unit_label":"Unit A revised","bedrooms":3,"bathrooms":2,"parking_spaces":1,"floor":2,"size_sq_ft":1500}'::jsonb);
 begin perform public.author_managed_inventory(gen_random_uuid(),'unit_update',unit,1,'{"unit_label":"Stale unit","bedrooms":3,"bathrooms":2,"parking_spaces":1,"floor":2,"size_sq_ft":1500}'::jsonb);raise exception 'Stale unit overwrite allowed';exception when serialization_failure then null;end;
 begin perform public.author_managed_inventory(gen_random_uuid(),'listing_link','55667788-0000-4000-8000-000000000008',1,jsonb_build_object('unit_id',unit));raise exception 'Manager linked catalog listing';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
do $$ declare result jsonb;begin
 result:=public.author_managed_inventory('55667788-0000-4000-8000-000000000022','listing_link','55667788-0000-4000-8000-000000000008',1,jsonb_build_object('unit_id',current_setting('openhouse.test_unit')));
 if result->>'unit_id'<>current_setting('openhouse.test_unit') or (result->>'revision')::integer<>2 then raise exception 'Listing unit linkage failure';end if;
 perform public.author_managed_inventory('55667788-0000-4000-8000-000000000022','listing_link','55667788-0000-4000-8000-000000000008',1,jsonb_build_object('unit_id',current_setting('openhouse.test_unit')));
 begin update public.listings set unit_id=null where id='55667788-0000-4000-8000-000000000008';raise exception 'Direct linkage bypass allowed';exception when insufficient_privilege then null;end;
 begin perform public.author_managed_inventory(gen_random_uuid(),'listing_link','55667788-0000-4000-8000-000000000008',1,'{"unit_id":null}'::jsonb);raise exception 'Stale linkage accepted';exception when serialization_failure then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.properties) or exists(select 1 from public.units) or exists(select 1 from public.managed_inventory_events) then raise exception 'Foreign inventory disclosure';end if;
 begin perform public.author_managed_inventory(gen_random_uuid(),'property_update',current_setting('openhouse.test_property')::uuid,2,'{"name":"Foreign edit","area":"Kingston","address_text":"Foreign exact address"}'::jsonb);raise exception 'Foreign property edit allowed';exception when insufficient_privilege then null;end;
 begin perform public.author_managed_inventory(gen_random_uuid(),'listing_link','55667788-0000-4000-8000-000000000008',2,jsonb_build_object('unit_id',current_setting('openhouse.test_unit')));raise exception 'Foreign listing link allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin
 if exists(select 1 from public.properties) or exists(select 1 from public.managed_inventory_events) then raise exception 'Unverified staff private disclosure';end if;
 begin perform public.author_managed_inventory(gen_random_uuid(),'property_create',null,0,'{"name":"Unverified edit","area":"Kingston","address_text":"Unverified exact address"}'::jsonb);raise exception 'Unverified author allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.properties) or exists(select 1 from public.units) or exists(select 1 from public.managed_inventory_events) then raise exception 'Prospect private inventory disclosure';end if;end $$;
rollback;
