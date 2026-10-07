begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('44556677-0000-4000-8000-000000000001','seller@example.invalid',now()),
 ('44556677-0000-4000-8000-000000000002','other@example.invalid',now()),
 ('44556677-0000-4000-8000-000000000003','staff@example.invalid',now()),
 ('44556677-0000-4000-8000-000000000004','foreign@example.invalid',now()),
 ('44556677-0000-4000-8000-000000000005','unverified@example.invalid',null);
insert into public.organizations(id,name) values ('44556677-0000-4000-8000-000000000006','Seller fixtures'),('44556677-0000-4000-8000-000000000007','Foreign seller fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values ('44556677-0000-4000-8000-000000000003','44556677-0000-4000-8000-000000000006','realtor'),('44556677-0000-4000-8000-000000000004','44556677-0000-4000-8000-000000000007','admin');
insert into public.realtor_profiles(id,organization_id,display_name,bio,service_areas,supported_intents,communication_style,guidance_style,decision_pace,is_published) values
 ('44556677-0000-4000-8000-000000000008','44556677-0000-4000-8000-000000000006','Seller fixture realtor','A verified-length professional fixture biography.',array['Kingston'],array['sell'],'thoughtful','step-by-step','considered',true),
 ('44556677-0000-4000-8000-000000000009','44556677-0000-4000-8000-000000000006','Rental-only fixture realtor','A verified-length professional fixture biography.',array['Kingston'],array['rent'],'thoughtful','step-by-step','considered',true);
insert into auth.users(id,email,email_confirmed_at) values ('44556677-0000-4000-8000-000000000017','manager@example.invalid',now());
insert into public.staff_accounts(user_id,organization_id,role) values ('44556677-0000-4000-8000-000000000017','44556677-0000-4000-8000-000000000006','manager'),('44556677-0000-4000-8000-000000000005','44556677-0000-4000-8000-000000000006','realtor');
insert into public.properties(id,organization_id,name,address_text) values ('44556677-0000-4000-8000-000000000020','44556677-0000-4000-8000-000000000006','Other own property','Private other address'),('44556677-0000-4000-8000-000000000021','44556677-0000-4000-8000-000000000007','Foreign property','Private foreign address');
insert into public.units(id,property_id,unit_label) values ('44556677-0000-4000-8000-000000000022','44556677-0000-4000-8000-000000000020','Own unit'),('44556677-0000-4000-8000-000000000023','44556677-0000-4000-8000-000000000021','Foreign unit');
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.test_seller_id',public.submit_seller_request('44556677-0000-4000-8000-000000000010','44556677-0000-4000-8000-000000000008','Test Seller','','Private fixture address 1','Kingston','house','considering','Please help me review this property.',true)::text,true);
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000003',true);
do $$ declare lead uuid:=current_setting('openhouse.test_seller_id')::uuid; draft jsonb; retry jsonb; listing uuid; prop uuid;begin
 begin perform public.prepare_seller_listing(lead,'44556677-0000-4000-8000-000000000011','Approved public title','Kingston','house','Seller authorized preparation.',true);raise exception 'Unreviewed proposal accepted';exception when invalid_parameter_value then null;end;
 perform public.transition_seller_request(lead,'contacted','Reached seller by phone.','new');
 perform public.transition_seller_request(lead,'market_review','Reviewed property details.','contacted');
 perform public.transition_seller_request(lead,'proposal','Discussed proposal with seller.','market_review');
 begin perform public.prepare_seller_listing(lead,'44556677-0000-4000-8000-000000000011','Approved public title','Kingston','house','Seller authorized preparation.',false);raise exception 'Missing seller approval accepted';exception when invalid_parameter_value then null;end;
 draft:=public.prepare_seller_listing(lead,'44556677-0000-4000-8000-000000000011','Approved public title','Kingston','house','Seller authorized preparation.',true);
 retry:=public.prepare_seller_listing(lead,'44556677-0000-4000-8000-000000000011','Approved public title','Kingston','house','Seller authorized preparation.',true);
 if draft<>retry then raise exception 'Handoff retry returned another draft';end if;
 listing:=(draft->>'listing_id')::uuid;prop:=(draft->>'property_id')::uuid;
 perform set_config('openhouse.test_listing_id',listing::text,true);
 if (select count(*) from public.seller_listing_handoffs)<>1 or (select count(*) from public.properties)<>2 then raise exception 'Duplicate handoff property created';end if;
 if (select address_text from public.properties where id=prop)<>'Private fixture address 1' then raise exception 'Private property address not retained';end if;
 if not exists(select 1 from public.listings where id=listing and status='draft' and property_id=prop and title='Approved public title' and description='' and photo_url is null and approximate_latitude is null) then raise exception 'Draft public data not isolated';end if;
 if (select status from public.seller_leads where id=lead)<>'proposal' then raise exception 'Draft prematurely marked seller listed';end if;
 begin perform public.prepare_seller_listing(lead,'44556677-0000-4000-8000-000000000012','Approved public title','Kingston','house','Seller authorized preparation.',true);raise exception 'Second handoff allowed' using errcode='XX000';exception when raise_exception then null;end;
 begin update public.listings set property_id='44556677-0000-4000-8000-000000000021' where id=listing;raise exception 'Foreign property link accepted';exception when invalid_parameter_value or insufficient_privilege then null;end;
 begin update public.listings set property_id='44556677-0000-4000-8000-000000000020' where id=listing;raise exception 'Handoff reassigned to unrelated own property';exception when invalid_parameter_value or insufficient_privilege then null;end;
 begin update public.listings set unit_id='44556677-0000-4000-8000-000000000023' where id=listing;raise exception 'Foreign unit link accepted';exception when invalid_parameter_value or insufficient_privilege then null;end;
 begin update public.listings set unit_id='44556677-0000-4000-8000-000000000022' where id=listing;raise exception 'Unrelated own unit accepted';exception when invalid_parameter_value or insufficient_privilege then null;end;
 begin perform public.author_managed_inventory(gen_random_uuid(),'listing_link',listing,1,jsonb_build_object('unit_id','44556677-0000-4000-8000-000000000022'));raise exception 'Handoff linked to unrelated managed property';exception when invalid_parameter_value then null;end;
 begin perform public.author_managed_inventory(gen_random_uuid(),'listing_link',listing,1,jsonb_build_object('unit_id','44556677-0000-4000-8000-000000000023'));raise exception 'Handoff linked to foreign unit';exception when insufficient_privilege then null;end;
 perform public.author_managed_inventory(gen_random_uuid(),'listing_link',listing,1,jsonb_build_object('unit_id',public.author_managed_inventory(gen_random_uuid(),'unit_create',prop,1,'{"unit_label":"Handoff unit","bedrooms":2,"bathrooms":1,"parking_spaces":1,"floor":null,"size_sq_ft":1200}'::jsonb)->>'unit_id'));

 begin update public.listings set status='published' where id=listing;raise exception 'Incomplete draft published';exception when check_violation then null;end;
 if (select status from public.seller_leads where id=lead)<>'proposal' then raise exception 'Failed publication advanced seller stage';end if;
 begin update public.listings set description='Approved public property description.',photo_url='https://example.invalid/approved.jpg',status='published' where id=listing;raise exception 'Zero-price draft published';exception when check_violation then null;end;
 update public.listings set description='Approved public property description.',price_jmd=10000000,photo_url='https://example.invalid/approved.jpg',status='published' where id=listing;
 if (select status from public.seller_leads where id=lead)<>'listed' then raise exception 'Published draft did not advance seller';end if;
 update public.listings set status='paused' where id=listing;
 update public.listings set status='published' where id=listing;
 if (select count(*) from public.seller_lead_events where seller_lead_id=lead and new_status='listed')<>1 then raise exception 'Publication audit duplicated';end if;
 retry:=public.prepare_seller_listing(lead,'44556677-0000-4000-8000-000000000011','Approved public title','Kingston','house','Seller authorized preparation.',true);
 if retry<>draft then raise exception 'Published handoff retry failed';end if;
end $$;
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000001',true);
select set_config('openhouse.test_inactive_seller_id',public.submit_seller_request('44556677-0000-4000-8000-000000000030','44556677-0000-4000-8000-000000000008','Test Seller','','Private fixture address 2','Kingston','house','considering','Please help me review a second property.',true)::text,true);
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000003',true);
do $$ declare lead uuid:=current_setting('openhouse.test_inactive_seller_id')::uuid;draft jsonb;begin
 perform public.transition_seller_request(lead,'contacted','Reached seller by phone.','new');
 perform public.transition_seller_request(lead,'market_review','Reviewed property details.','contacted');
 perform public.transition_seller_request(lead,'proposal','Discussed proposal with seller.','market_review');
 draft:=public.prepare_seller_listing(lead,'44556677-0000-4000-8000-000000000031','Second public title','Kingston','house','Seller authorized preparation.',true);
 perform public.transition_seller_request(lead,'closed','Seller withdrew the proposal.','proposal');
 begin update public.listings set description='Approved public property description.',price_jmd=10000000,photo_url='https://example.invalid/approved.jpg',status='published' where id=(draft->>'listing_id')::uuid;raise exception 'Inactive proposal published';exception when invalid_parameter_value then null;end;
 if (select status from public.listings where id=(draft->>'listing_id')::uuid)<>'draft' then raise exception 'Failed publication left a public listing';end if;
end $$;
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000017',true);
do $$ begin
 begin perform public.prepare_seller_listing(current_setting('openhouse.test_seller_id')::uuid,'44556677-0000-4000-8000-000000000011','Approved public title','Kingston','house','Seller authorized preparation.',true);raise exception 'Manager authored catalog handoff';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.seller_listing_handoffs) then raise exception 'Foreign staff handoff disclosure';end if;
 begin perform public.prepare_seller_listing(current_setting('openhouse.test_seller_id')::uuid,'44556677-0000-4000-8000-000000000011','Approved public title','Kingston','house','Seller authorized preparation.',true);raise exception 'Foreign staff handoff allowed';exception when insufficient_privilege then null;end;
 begin insert into public.listings(organization_id,property_id,title,area,intent,property_type,status,price_jmd) values('44556677-0000-4000-8000-000000000007','44556677-0000-4000-8000-000000000020','Spoofed cross-org listing','Kingston','sale','house','draft',0);raise exception 'Cross-org insert relation allowed';exception when invalid_parameter_value or insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000005',true);
do $$ begin
 if exists(select 1 from public.properties) or exists(select 1 from public.units) or exists(select 1 from public.seller_listing_handoffs) then raise exception 'Unverified private property access';end if;
 update public.listings set title='Unverified author' where id=current_setting('openhouse.test_listing_id')::uuid;
 if found then raise exception 'Unverified staff catalog update allowed';end if;
 begin insert into public.listings(organization_id,title,area,intent,property_type,status,price_jmd) values('44556677-0000-4000-8000-000000000006','Unverified draft','Kingston','sale','house','draft',0);raise exception 'Unverified catalog insert';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000001',true);
do $$ begin
 if exists(select 1 from public.properties) or exists(select 1 from public.units) or exists(select 1 from public.seller_listing_handoffs) then raise exception 'Seller granted internal catalog/property access';end if;
 if not exists(select 1 from public.seller_leads where listing_id=current_setting('openhouse.test_listing_id')::uuid and status='listed') then raise exception 'Seller publication handoff missing';end if;
 if not exists(select 1 from public.listings where id=current_setting('openhouse.test_listing_id')::uuid and status='published') then raise exception 'Seller cannot see published listing';end if;
end $$;
reset role;
set local role anon;
do $$ declare item public.listings;begin
 select * into item from public.listings where id=current_setting('openhouse.test_listing_id')::uuid;
 if item.id is null or position('Private fixture address 1' in to_jsonb(item)::text)>0 then raise exception 'Public listing exposed private address';end if;
 begin perform count(*) from public.properties;raise exception 'Anonymous property reads allowed';exception when insufficient_privilege then null;end;
 begin perform count(*) from public.units;raise exception 'Anonymous unit reads allowed';exception when insufficient_privilege then null;end;
 begin perform count(*) from public.seller_listing_handoffs;raise exception 'Anonymous handoff audit reads allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: approved proposal handoff/retry/audit, private address/public draft separation, manager/foreign/unverified restrictions, immutable same-org property/unit relations, publication validation and single listed event. Fixtures rolled back; no email sent.' as verification;
