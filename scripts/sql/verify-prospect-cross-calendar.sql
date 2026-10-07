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
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
set local role authenticated;
select set_config('openhouse.calendar_event',public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Cross calendar fixture',now()+interval '2 days',now()+interval '2 days 1 hour',12,null,true)->>'event_id',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
select set_config('openhouse.calendar_slot',public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000009',now()+interval '2 days',now()+interval '2 days 1 hour')::text,true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.reserve_open_house(current_setting('openhouse.calendar_event')::uuid,gen_random_uuid(),0,1,'reserve',true);
do $$ begin begin perform public.request_viewing(gen_random_uuid(),current_setting('openhouse.calendar_slot')::uuid,null,'Calendar prospect','',true);raise exception 'Viewing overlapped own RSVP';exception when unique_violation then null;end;end $$;
select public.reserve_open_house(current_setting('openhouse.calendar_event')::uuid,gen_random_uuid(),1,null,'cancel',null);
select set_config('openhouse.calendar_booking',public.request_viewing(gen_random_uuid(),current_setting('openhouse.calendar_slot')::uuid,null,'Calendar prospect','',true)::text,true);
do $$ begin begin perform public.reserve_open_house(current_setting('openhouse.calendar_event')::uuid,gen_random_uuid(),2,1,'reserve',true);raise exception 'RSVP overlapped active viewing hold';exception when unique_violation then null;end;end $$;
reset role;
update public.viewings set hold_expires_at=now()-interval '1 minute' where id=current_setting('openhouse.calendar_booking')::uuid;
update public.viewing_slots set hold_expires_at=now()-interval '1 minute' where id=current_setting('openhouse.calendar_slot')::uuid;
set local role authenticated;
select public.reserve_open_house(current_setting('openhouse.calendar_event')::uuid,gen_random_uuid(),2,1,'reserve',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.transition_viewing(current_setting('openhouse.calendar_booking')::uuid,'confirm','Staff fixture confirmation');
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
select public.request_viewing(gen_random_uuid(),current_setting('openhouse.calendar_slot')::uuid,null,'Other calendar prospect','',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
select set_config('openhouse.adjacent_slot',public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000009',now()+interval '2 days 1 hour',now()+interval '2 days 2 hours')::text,true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.request_viewing(gen_random_uuid(),current_setting('openhouse.adjacent_slot')::uuid,null,'Calendar prospect','',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select set_config('openhouse.confirm_event',public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Confirmed calendar fixture',now()+interval '4 days',now()+interval '4 days 1 hour',12,null,true)->>'event_id',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
select set_config('openhouse.confirm_slot',public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000009',now()+interval '4 days',now()+interval '4 days 1 hour')::text,true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select set_config('openhouse.confirm_booking',public.request_viewing(gen_random_uuid(),current_setting('openhouse.confirm_slot')::uuid,null,'Calendar prospect','',true)::text,true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.transition_viewing(current_setting('openhouse.confirm_booking')::uuid,'confirm','Staff fixture confirmation');
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin begin perform public.reserve_open_house(current_setting('openhouse.confirm_event')::uuid,gen_random_uuid(),0,1,'reserve',true);raise exception 'RSVP overlapped confirmed viewing';exception when unique_violation then null;end;end $$;
select public.transition_viewing(current_setting('openhouse.confirm_booking')::uuid,'cancel','Prospect chose the open house');
select public.reserve_open_house(current_setting('openhouse.confirm_event')::uuid,gen_random_uuid(),0,1,'reserve',true);
reset role;
do $$ begin
 begin update public.open_house_events set starts_at=starts_at+interval '1 minute',ends_at=ends_at+interval '1 minute' where id=current_setting('openhouse.confirm_event')::uuid;raise exception 'Reserved schedule changed';exception when unique_violation then null;end;
 update public.open_house_events set starts_at=starts_at where id=current_setting('openhouse.confirm_event')::uuid;
end $$;
rollback;
