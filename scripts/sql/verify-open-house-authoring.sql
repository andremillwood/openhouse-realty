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
select set_config('openhouse.test_event',public.author_open_house_event('create','55667788-0000-4000-8000-000000000070',null,0,'55667788-0000-4000-8000-000000000008','Approved open house',now()+interval '2 days',now()+interval '2 days 2 hours',12,null,true)->>'event_id',true);
do $$ begin
 if public.author_open_house_event('create','55667788-0000-4000-8000-000000000070',null,0,'55667788-0000-4000-8000-000000000008','Approved open house',now()+interval '2 days',now()+interval '2 days 2 hours',12,null,true)->>'event_id'<>current_setting('openhouse.test_event') or (select count(*) from public.open_house_author_events)<>1 then raise exception 'Open house retry duplicated';end if;
 if not exists(select 1 from public.open_house_management where event_id=current_setting('openhouse.test_event')::uuid and host_user_id=auth.uid() and organization_id='55667788-0000-4000-8000-000000000006') then raise exception 'Derived organization/host missing';end if;
 begin perform public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000009','Same host collision',now()+interval '2 days',now()+interval '2 days 2 hours',12,null,true);raise exception 'Open house host conflict accepted';exception when unique_violation then null;end;
 begin perform public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000008',now()+interval '2 days',now()+interval '2 days 1 hour');raise exception 'Viewing property collided with open house';exception when unique_violation then null;end;
 begin perform public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000009',now()+interval '2 days',now()+interval '2 days 1 hour');raise exception 'Viewing host collided with open house';exception when unique_violation then null;end;
 if exists(select 1 from public.viewing_slots) then raise exception 'Rejected host creation left an orphan viewing slot';end if;
 begin perform public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Unapproved event',now()+interval '4 days',now()+interval '4 days 2 hours',12,null,false);raise exception 'Unapproved event accepted';exception when invalid_parameter_value then null;end;
 begin update public.open_house_events set status='cancelled';raise exception 'Staff bypassed audited event change';exception when insufficient_privilege then null;end;
 begin perform public.author_open_house_event('complete',gen_random_uuid(),current_setting('openhouse.test_event')::uuid,1,null,null,null,null,null,'Completed before event end',null);raise exception 'Future event completed';exception when invalid_parameter_value then null;end;
 begin perform public.author_open_house_event('cancel',gen_random_uuid(),current_setting('openhouse.test_event')::uuid,2,null,null,null,null,null,'Stale cancellation attempted',null);raise exception 'Stale event canceled';exception when serialization_failure then null;end;
end $$;
select public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000009',now()+interval '4 days',now()+interval '4 days 1 hour');
do $$ begin begin perform public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Host viewing conflict',now()+interval '4 days',now()+interval '4 days 2 hours',12,null,true);raise exception 'Open house collided with individual viewing';exception when unique_violation then null;end;end $$;
reset role;
set local role anon;
do $$ begin
 if not exists(select 1 from public.open_house_events where id=current_setting('openhouse.test_event')::uuid) then raise exception 'Published scheduled event hidden';end if;
 begin perform 1 from public.open_house_management;raise exception 'Anonymous saw host records';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.open_house_management) or exists(select 1 from public.open_house_author_events) then raise exception 'Foreign host/audit disclosure';end if;
 begin perform public.author_open_house_event('cancel',gen_random_uuid(),current_setting('openhouse.test_event')::uuid,1,null,null,null,null,null,'Foreign cancellation attempted',null);raise exception 'Foreign event cancellation';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin begin perform public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Unverified author attempt',now()+interval '5 days',now()+interval '5 days 2 hours',12,null,true);raise exception 'Unverified author accepted';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin begin perform public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Prospect author attempt',now()+interval '5 days',now()+interval '5 days 2 hours',12,null,true);raise exception 'Prospect author accepted';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.author_open_house_event('cancel','55667788-0000-4000-8000-000000000071',current_setting('openhouse.test_event')::uuid,1,null,null,null,null,null,'Event access no longer available',null);
select public.author_open_house_event('cancel','55667788-0000-4000-8000-000000000071',current_setting('openhouse.test_event')::uuid,1,null,null,null,null,null,'Event access no longer available',null);
select public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000008',now()+interval '2 days',now()+interval '2 days 1 hour');
reset role;
set local role anon;
do $$ begin if exists(select 1 from public.open_house_events where id=current_setting('openhouse.test_event')::uuid) then raise exception 'Cancelled event public';end if;end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select set_config('openhouse.test_finished',public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Completed event fixture',now()+interval '6 days',now()+interval '6 days 2 hours',12,null,true)->>'event_id',true);
reset role;
update public.open_house_events set starts_at=now()-interval '2 hours',ends_at=now()-interval '1 hour' where id=current_setting('openhouse.test_finished')::uuid;
set local role authenticated;
select public.author_open_house_event('complete',gen_random_uuid(),current_setting('openhouse.test_finished')::uuid,1,null,null,null,null,null,'Host confirmed event completion',null);
rollback;
