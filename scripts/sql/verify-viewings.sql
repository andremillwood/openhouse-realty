begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('33445566-0000-4000-8000-000000000001','view-prospect-one@example.invalid',now()),
 ('33445566-0000-4000-8000-000000000002','view-prospect-two@example.invalid',now()),
 ('33445566-0000-4000-8000-000000000003','view-host-one@example.invalid',now()),
 ('33445566-0000-4000-8000-000000000004','view-host-two@example.invalid',now()),
 ('33445566-0000-4000-8000-000000000005','view-other-staff@example.invalid',now());
insert into public.organizations(id,name) values ('33445566-0000-4000-8000-000000000006','Viewing test one'),('33445566-0000-4000-8000-000000000007','Viewing test two');
insert into public.staff_accounts(user_id,organization_id,role) values
 ('33445566-0000-4000-8000-000000000003','33445566-0000-4000-8000-000000000006','realtor'),
 ('33445566-0000-4000-8000-000000000004','33445566-0000-4000-8000-000000000006','manager'),
 ('33445566-0000-4000-8000-000000000005','33445566-0000-4000-8000-000000000007','realtor');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values
 ('33445566-0000-4000-8000-000000000008','33445566-0000-4000-8000-000000000006','Viewing fixture one','Test','rent','house','published',100,'A sufficiently complete fixture description.','https://example.invalid/fixture.jpg'),
 ('33445566-0000-4000-8000-000000000009','33445566-0000-4000-8000-000000000006','Viewing fixture two','Test','rent','house','published',100,'A sufficiently complete fixture description.','https://example.invalid/fixture.jpg');
select set_config('request.jwt.claim.sub','33445566-0000-4000-8000-000000000003',true);
set local role authenticated;
select public.manage_viewing_slot('create','33445566-0000-4000-8000-000000000010',null,'33445566-0000-4000-8000-000000000008',now()+interval '2 days',now()+interval '2 days 30 minutes');
select public.manage_viewing_slot('create','33445566-0000-4000-8000-000000000010',null,'33445566-0000-4000-8000-000000000008',now()+interval '2 days',now()+interval '2 days 30 minutes');
do $$ begin
 if (select count(*) from public.viewing_slots where organization_id='33445566-0000-4000-8000-000000000006')<>1 then raise exception 'Slot idempotency failure'; end if;
 begin
  perform public.manage_viewing_slot('create','33445566-0000-4000-8000-000000000011',null,'33445566-0000-4000-8000-000000000009',now()+interval '2 days',now()+interval '2 days 30 minutes');
  raise exception 'Host conflict accepted' using errcode='XX000';
 exception when raise_exception then null; end;
end $$;
select set_config('request.jwt.claim.sub','33445566-0000-4000-8000-000000000004',true);
select public.manage_viewing_slot('create','33445566-0000-4000-8000-000000000012',null,'33445566-0000-4000-8000-000000000009',now()+interval '2 days',now()+interval '2 days 30 minutes');
do $$ begin
 begin
  perform public.manage_viewing_slot('create','33445566-0000-4000-8000-000000000013',null,'33445566-0000-4000-8000-000000000008',now()+interval '2 days',now()+interval '2 days 30 minutes');
  raise exception 'Property conflict accepted' using errcode='XX000';
 exception when raise_exception then null; end;
end $$;
select set_config('request.jwt.claim.sub','33445566-0000-4000-8000-000000000005',true);
do $$ begin
 begin
  perform public.manage_viewing_slot('create','33445566-0000-4000-8000-000000000014',null,'33445566-0000-4000-8000-000000000008',now()+interval '3 days',now()+interval '3 days 30 minutes');
  raise exception 'Cross-organization slot creation accepted';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
 if (select count(*) from public.viewing_slots where organization_id='33445566-0000-4000-8000-000000000006')<>2 then raise exception 'Public availability unavailable'; end if;
 begin
  perform public.request_viewing('33445566-0000-4000-8000-000000000015',gen_random_uuid(),null,'Test','','true');
  raise exception 'Anonymous booking accepted';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','33445566-0000-4000-8000-000000000001',true);
set local role authenticated;
select public.request_viewing('33445566-0000-4000-8000-000000000015',(select id from public.viewing_slots where request_id='33445566-0000-4000-8000-000000000010'),null,'Test prospect','',true);
-- Owner reads its held slot indirectly through the viewing; no prospect identities are public.
select public.request_viewing('33445566-0000-4000-8000-000000000015',(select slot_id from public.viewings where request_id='33445566-0000-4000-8000-000000000015'),null,'Test prospect','',true);
do $$ declare booking uuid; begin
 select id into booking from public.viewings where request_id='33445566-0000-4000-8000-000000000015';
 if (select count(*) from public.viewings where user_id='33445566-0000-4000-8000-000000000001')<>1 then raise exception 'Duplicate viewing accepted'; end if;
 begin perform public.transition_viewing(booking,'confirm','');raise exception 'Prospect self-confirmation accepted';exception when insufficient_privilege then null;end;
 begin
  perform public.request_viewing('33445566-0000-4000-8000-000000000016',(select id from public.viewing_slots where request_id='33445566-0000-4000-8000-000000000012'),null,'Test prospect','',true);
  raise exception 'Prospect overlap accepted' using errcode='XX000';
 exception when raise_exception then null;end;
 begin update public.viewings set status='confirmed' where id=booking;raise exception 'Direct status write accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ declare slot uuid; begin
 select slot_id into slot from public.viewings where request_id='33445566-0000-4000-8000-000000000015';
 begin insert into public.viewings(user_id,listing_id,requested_for,slot_id) values('33445566-0000-4000-8000-000000000002','33445566-0000-4000-8000-000000000008',now()+interval '2 days',slot);raise exception 'Unique active slot guard missing';exception when unique_violation then null;end;
 if (select count(*) from private.notification_outbox where viewing_event_id in(select id from public.viewing_events where viewing_id in(select id from public.viewings where request_id='33445566-0000-4000-8000-000000000015')))<>2 then raise exception 'Initial viewing notifications duplicated';end if;
end $$;
select set_config('request.jwt.claim.sub','33445566-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.viewings where request_id='33445566-0000-4000-8000-000000000015') then raise exception 'Cross-prospect read accepted';end if;
end $$;
reset role;
-- Keep the target ID private to this administrative test context.
select set_config('viewing.test_id',(select id::text from public.viewings where request_id='33445566-0000-4000-8000-000000000015'),true);
select set_config('viewing.test_slot',(select slot_id::text from public.viewings where request_id='33445566-0000-4000-8000-000000000015'),true);
set local role authenticated;
do $$ begin
 begin perform public.transition_viewing(current_setting('viewing.test_id')::uuid,'cancel','Wrong owner test');raise exception 'Cross-prospect cancellation accepted';exception when insufficient_privilege then null;end;
 begin perform public.request_viewing('33445566-0000-4000-8000-000000000017',current_setting('viewing.test_slot')::uuid,null,'Other prospect','',true);raise exception 'Double booking accepted' using errcode='XX000';exception when raise_exception then null;end;
end $$;
select set_config('request.jwt.claim.sub','33445566-0000-4000-8000-000000000005',true);
do $$ begin
 begin perform public.transition_viewing(current_setting('viewing.test_id')::uuid,'confirm','');raise exception 'Cross-organization confirmation accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','33445566-0000-4000-8000-000000000003',true);
select public.transition_viewing(current_setting('viewing.test_id')::uuid,'confirm','');
select public.transition_viewing(current_setting('viewing.test_id')::uuid,'confirm','');
do $$ begin
 if (select count(*) from public.viewing_events where viewing_id=current_setting('viewing.test_id')::uuid and event_name='confirm')<>1 then raise exception 'Duplicate confirmation audit';end if;
 begin perform public.transition_viewing(current_setting('viewing.test_id')::uuid,'complete','');raise exception 'Early completion accepted' using errcode='XX000';exception when raise_exception then null;end;
end $$;
select set_config('request.jwt.claim.sub','33445566-0000-4000-8000-000000000001',true);
select public.transition_viewing(current_setting('viewing.test_id')::uuid,'cancel','My plans have changed.');
select public.transition_viewing(current_setting('viewing.test_id')::uuid,'cancel','My plans have changed.');
reset role;
do $$ begin
 if (select state from public.viewing_slots where id=current_setting('viewing.test_slot')::uuid)<>'open' then raise exception 'Cancellation did not release future capacity';end if;
 if (select count(*) from public.viewing_events where viewing_id=current_setting('viewing.test_id')::uuid and event_name='cancel')<>1 then raise exception 'Duplicate cancellation audit';end if;
 if (select count(*) from private.notification_outbox where state='pending' and viewing_event_id in(select id from public.viewing_events where viewing_id=current_setting('viewing.test_id')::uuid))<>2 then raise exception 'Stale notifications not superseded';end if;
end $$;
select set_config('request.jwt.claim.sub','33445566-0000-4000-8000-000000000002',true);
set local role authenticated;
select public.request_viewing('33445566-0000-4000-8000-000000000018',current_setting('viewing.test_slot')::uuid,null,'Second prospect','',true);
reset role;
-- Simulate an elapsed hold using rolled-back administrative fixtures.
update public.viewings set hold_expires_at=now()-interval '1 minute' where request_id='33445566-0000-4000-8000-000000000018';
update public.viewing_slots set hold_expires_at=now()-interval '1 minute' where id=current_setting('viewing.test_slot')::uuid;
select set_config('request.jwt.claim.sub','33445566-0000-4000-8000-000000000001',true);
set local role authenticated;
select public.request_viewing('33445566-0000-4000-8000-000000000019',current_setting('viewing.test_slot')::uuid,null,'Test prospect','',true);
reset role;
do $$ begin
 if (select status from public.viewings where request_id='33445566-0000-4000-8000-000000000018')<>'expired' then raise exception 'Elapsed hold not expired';end if;
 if exists(select 1 from public.viewing_events where viewing_id in(select id from public.viewings where request_id='33445566-0000-4000-8000-000000000018') and event_name='hold_expired' and actor_user_id is not null) then raise exception 'Expiry exposed another prospect identity';end if;
end $$;
set local role service_role;
do $$ declare job record; count_viewing integer:=0; begin
 for job in select * from public.claim_enquiry_notifications('sender@example.invalid','business@example.invalid') loop
  if job.subject_snapshot is null or job.text_snapshot is null or job.enquiry_id is not null then raise exception 'Viewing queue payload missing or misclassified'; end if;
  if job.recipient not in('business@example.invalid','view-prospect-one@example.invalid','view-prospect-two@example.invalid') then raise exception 'Viewing recipient identity failure'; end if;
  if job.text_snapshot not like '%Time (Jamaica):%' then raise exception 'Viewing notification timezone absent'; end if;
  count_viewing:=count_viewing+1;
 end loop;
 if count_viewing<2 then raise exception 'Viewing notifications not claimable'; end if;
end $$;
reset role;
rollback;
select 'PASS: slot/booking idempotency, property/host/prospect conflicts, active capacity uniqueness, public availability, private identity, staff-only confirmation, cancellation/release, elapsed holds, event audit and superseded notification safety. Fixtures rolled back; no email sent.' as verification;
