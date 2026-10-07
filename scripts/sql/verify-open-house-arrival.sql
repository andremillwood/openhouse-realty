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
delete from public.staff_accounts where user_id='55667788-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
set local role authenticated;
select set_config('openhouse.arrival_event',public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Arrival fixture',now()+interval '2 days',now()+interval '2 days 1 hour',12,null,true)->>'event_id',true);
do $$ begin begin perform public.author_open_house_arrival(current_setting('openhouse.arrival_event')::uuid,gen_random_uuid(),0,'save','Approved fixture meeting point','Approved fixture arrival details',18.02,-76.77,'Confirmed fixture directions',false);raise exception 'Unapproved private address accepted';exception when invalid_parameter_value then null;end;end $$;
select public.author_open_house_arrival(current_setting('openhouse.arrival_event')::uuid,'55667788-0000-4000-8000-000000000091',0,'save','Approved fixture meeting point','Approved fixture arrival details',18.02,-76.77,'Confirmed fixture directions',true);
select public.author_open_house_arrival(current_setting('openhouse.arrival_event')::uuid,'55667788-0000-4000-8000-000000000091',0,'save','Approved fixture meeting point','Approved fixture arrival details',18.02,-76.77,'Confirmed fixture directions',true);
do $$ begin
 if (select count(*) from public.open_house_arrival_changes)<>1 then raise exception 'Arrival retry duplicated audit';end if;
 begin update public.open_house_arrival set is_active=false;raise exception 'Staff bypassed approved change';exception when insufficient_privilege then null;end;
 begin perform public.author_open_house_arrival(current_setting('openhouse.arrival_event')::uuid,gen_random_uuid(),1,'save','Approved fixture meeting point','Approved fixture arrival details','NaN'::double precision,0,'Invalid coordinates fixture',true);raise exception 'Invalid coordinate accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.reserve_open_house(current_setting('openhouse.arrival_event')::uuid,gen_random_uuid(),0,1,'reserve',true);
do $$ begin if exists(select 1 from public.open_house_arrival) then raise exception 'Private arrival disclosed too early';end if;end $$;
reset role;
update public.open_house_events set starts_at=now()+interval '2 hours',ends_at=now()+interval '3 hours' where id=current_setting('openhouse.arrival_event')::uuid;
set local role authenticated;
do $$ begin
 if not exists(select 1 from public.open_house_arrival where meeting_point='Approved fixture meeting point' and latitude=18.02) then raise exception 'Imminent active RSVP arrival hidden';end if;
 if exists(select 1 from public.open_house_arrival_changes) then raise exception 'Private staff audit exposed to attendee';end if;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
do $$ begin if exists(select 1 from public.open_house_arrival) then raise exception 'Unreserved prospect arrival disclosure';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.open_house_arrival) then raise exception 'Foreign staff arrival disclosure';end if;
 begin perform public.author_open_house_arrival(current_setting('openhouse.arrival_event')::uuid,gen_random_uuid(),1,'withdraw',null,null,null,null,'Foreign withdrawal attempt',null);raise exception 'Foreign arrival edit';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin if exists(select 1 from public.open_house_arrival) then raise exception 'Unverified staff arrival disclosure';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.reserve_open_house(current_setting('openhouse.arrival_event')::uuid,gen_random_uuid(),1,null,'cancel',null);
do $$ begin if exists(select 1 from public.open_house_arrival) then raise exception 'Cancelled RSVP arrival disclosure';end if;end $$;
select public.reserve_open_house(current_setting('openhouse.arrival_event')::uuid,gen_random_uuid(),2,1,'reserve',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.author_open_house_arrival(current_setting('openhouse.arrival_event')::uuid,gen_random_uuid(),1,'withdraw',null,null,null,null,'Fixture directions withdrawn',null);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.open_house_arrival) then raise exception 'Withdrawn directions disclosed';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.author_open_house_arrival(current_setting('openhouse.arrival_event')::uuid,gen_random_uuid(),2,'save','Updated fixture meeting point','Updated approved fixture directions',null,null,'Reapproved fixture directions',true);
do $$ begin begin perform public.author_open_house_arrival(current_setting('openhouse.arrival_event')::uuid,gen_random_uuid(),2,'withdraw',null,null,null,null,'Stale withdrawal attempt',null);raise exception 'Stale arrival edited';exception when serialization_failure then null;end;end $$;
reset role;
update public.listings set status='paused' where id='55667788-0000-4000-8000-000000000008';
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.open_house_arrival) then raise exception 'Unpublished listing arrival disclosed';end if;end $$;
reset role;
update public.listings set status='published' where id='55667788-0000-4000-8000-000000000008';
update public.open_house_events set starts_at=now()-interval '2 hours',ends_at=now()-interval '1 hour' where id=current_setting('openhouse.arrival_event')::uuid;
set local role authenticated;
do $$ begin if exists(select 1 from public.open_house_arrival) then raise exception 'Ended event arrival disclosed';end if;end $$;
reset role;
update public.open_house_events set starts_at=now()+interval '2 hours',ends_at=now()+interval '3 hours' where id=current_setting('openhouse.arrival_event')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.author_open_house_event('cancel',gen_random_uuid(),current_setting('openhouse.arrival_event')::uuid,1,null,null,null,null,null,'Fixture event cancelled',null);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.open_house_arrival) then raise exception 'Cancelled event arrival disclosed';end if;end $$;
reset role;
set local role anon;
do $$ begin begin perform 1 from public.open_house_arrival;raise exception 'Anonymous arrival disclosure';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
