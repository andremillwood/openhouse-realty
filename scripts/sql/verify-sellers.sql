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
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ declare lead uuid; retry uuid; i integer; begin
 lead:=public.submit_seller_request('44556677-0000-4000-8000-000000000010','44556677-0000-4000-8000-000000000008','Test Seller','','Private fixture address 1','Kingston','house','considering','Please help me review this property.',true);
 perform set_config('openhouse.test_seller_id',lead::text,true);
 retry:=public.submit_seller_request('44556677-0000-4000-8000-000000000010','44556677-0000-4000-8000-000000000008','Test Seller','','Private fixture address 1','Kingston','house','considering','Please help me review this property.',true);
 if lead<>retry or (select count(*) from public.seller_leads)<>1 then raise exception 'Seller retry duplication';end if;
 if (select email from public.seller_leads where id=lead)<>'seller@example.invalid' or (select organization_id from public.seller_leads where id=lead)<>'44556677-0000-4000-8000-000000000006'::uuid then raise exception 'Seller trusted identity/routing failure';end if;
 begin perform public.submit_seller_request('44556677-0000-4000-8000-000000000010','44556677-0000-4000-8000-000000000008','Test Seller','','Altered private address','Kingston','house','considering','Please help me review this property.',true);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.submit_seller_request('44556677-0000-4000-8000-000000000011','44556677-0000-4000-8000-000000000008','Test Seller','','Private fixture address 1','Kingston','house','considering','Please help me review this property.',false);raise exception 'Missing consent accepted';exception when invalid_parameter_value then null;end;
 begin perform public.submit_seller_request('44556677-0000-4000-8000-000000000011','44556677-0000-4000-8000-000000000009','Test Seller','','Private fixture address 1','Kingston','house','considering','Please help me review this property.',true);raise exception 'Rental-only realtor accepted';exception when invalid_parameter_value then null;end;
 begin update public.seller_leads set status='listed';raise exception 'Direct status update accepted';exception when insufficient_privilege then null;end;
 begin perform public.transition_seller_request(lead,'contacted','Prospect trying to advance.','new');raise exception 'Seller staff transition allowed';exception when insufficient_privilege then null;end;
 for i in 11..12 loop perform public.submit_seller_request(('44556677-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'44556677-0000-4000-8000-000000000008','Test Seller','','Private fixture address 1','Kingston','house','considering','Please help me review this property.',true);end loop;
 begin perform public.submit_seller_request('44556677-0000-4000-8000-000000000013','44556677-0000-4000-8000-000000000008','Test Seller','','Private fixture address 1','Kingston','house','considering','Please help me review this property.',true);raise exception 'Fourth daily request accepted' using errcode='XX000';exception when raise_exception then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.seller_leads) or exists(select 1 from public.seller_lead_events) then raise exception 'Cross-seller private address/history exposure';end if;end $$;
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.seller_leads) then raise exception 'Foreign staff sees seller address';end if;
 begin perform public.transition_seller_request(current_setting('openhouse.test_seller_id')::uuid,'contacted','Foreign follow-up.','new');raise exception 'Foreign staff transition allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000003',true);
do $$ declare lead uuid:=current_setting('openhouse.test_seller_id')::uuid;begin
 if (select count(*) from public.seller_leads)<>3 then raise exception 'Staff cannot read organization requests';end if;
 begin perform public.transition_seller_request(lead,'proposal','Skipping property review.','new');raise exception 'Skipped review stage accepted';exception when invalid_parameter_value then null;end;
 perform public.transition_seller_request(lead,'contacted','Reached seller by phone.','new');
 perform public.transition_seller_request(lead,'contacted','Reached seller by phone.','new');
 if (select count(*) from public.seller_lead_events where seller_lead_id=lead)<>2 then raise exception 'Status retry audit duplication';end if;
 begin perform public.transition_seller_request(lead,'market_review','Review property details.','new');raise exception 'Stale stage update allowed';exception when serialization_failure then null;end;
 perform public.transition_seller_request(lead,'market_review','Review property details.','contacted');
 perform public.transition_seller_request(lead,'proposal','Discuss proposed next steps.','market_review');
 begin perform public.transition_seller_request(lead,'listed','Publish without listing approval.','proposal');raise exception 'Unapproved listing status accepted';exception when invalid_parameter_value then null;end;
 perform public.transition_seller_request(lead,'closed','Seller paused their plans.','proposal');
 begin perform public.transition_seller_request(lead,'contacted','Reopening terminal request.','closed');raise exception 'Terminal request reopened';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000001',true);
do $$ begin if not exists(select 1 from public.seller_lead_events where reason='Seller paused their plans.') then raise exception 'Seller shared follow-up history missing';end if;end $$;
select set_config('request.jwt.claim.sub','44556677-0000-4000-8000-000000000005',true);
do $$ begin
 begin perform public.submit_seller_request('44556677-0000-4000-8000-000000000014','44556677-0000-4000-8000-000000000008','Test Seller','','Private fixture address 1','Kingston','house','considering','Please help me review this property.',true);raise exception 'Unverified seller accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin insert into public.seller_leads(property_address,seller_intent) values('Anonymous spoofing address','curious');raise exception 'Anonymous direct insert accepted';exception when insufficient_privilege then null;end;
 begin perform public.submit_seller_request('44556677-0000-4000-8000-000000000014','44556677-0000-4000-8000-000000000008','Test Seller','','Private fixture address 1','Kingston','house','considering','Please help me review this property.',true);raise exception 'Anonymous RPC accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 if (select count(*) from private.notification_outbox where seller_lead_id is not null and seller_lead_id in(select id from public.seller_leads where user_id='44556677-0000-4000-8000-000000000001'))<>3 then raise exception 'Seller outbox missing or duplicated';end if;
end $$;
set local role service_role;
do $$ declare job record;claimed integer:=0;begin
 for job in select * from public.claim_enquiry_notifications('sender@example.invalid','business@example.invalid') loop
  if job.subject_snapshot='New seller property-review request' then
   claimed:=claimed+1;
   if job.recipient<>'business@example.invalid' or position('seller@example.invalid' in job.text_snapshot)=0 or position('Private fixture address 1' in job.text_snapshot)=0 then raise exception 'Seller frozen notification payload failure';end if;
  end if;
 end loop;
 if claimed<>3 then raise exception 'Seller jobs not claimed by generic queue worker';end if;
end $$;
reset role;
rollback;
select 'PASS: seller verified identity/routing/consent/idempotency/rate limits, private address isolation, staff stage conflicts/audit/review gates, retired anonymous writes and frozen business notification payloads. Fixtures rolled back; no email sent.' as verification;
