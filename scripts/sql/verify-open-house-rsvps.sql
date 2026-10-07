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
select set_config('openhouse.test_event',public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','RSVP fixture event',now()+interval '2 days',now()+interval '2 days 1 hour',3,null,true)->>'event_id',true);
reset role;
insert into auth.users(id,email,email_confirmed_at) values ('55667788-0000-4000-8000-000000000020','second-host@example.invalid',now());
insert into public.staff_accounts(user_id,organization_id,role) values ('55667788-0000-4000-8000-000000000020','55667788-0000-4000-8000-000000000006','manager');
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000020',true);
select set_config('openhouse.second_event',public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000009','Second hosted event',now()+interval '2 days',now()+interval '2 days 1 hour',3,null,true)->>'event_id',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.reserve_open_house(current_setting('openhouse.test_event')::uuid,'55667788-0000-4000-8000-000000000080',0,2,'reserve',true);
select public.reserve_open_house(current_setting('openhouse.test_event')::uuid,'55667788-0000-4000-8000-000000000080',0,2,'reserve',true);
do $$ begin
 begin perform public.reserve_open_house(current_setting('openhouse.second_event')::uuid,gen_random_uuid(),0,1,'reserve',true);raise exception 'Overlapping prospect RSVPs accepted';exception when unique_violation then null;end;
 if (select count(*) from public.open_house_rsvps)<>1 or (select count(*) from public.open_house_rsvp_changes)<>1 then raise exception 'Retry duplicated reservation or audit';end if;
 begin perform public.reserve_open_house(current_setting('openhouse.test_event')::uuid,gen_random_uuid(),0,1,'reserve',true);raise exception 'Stale reservation update accepted';exception when serialization_failure then null;end;
 begin update public.open_house_rsvps set party_size=6;raise exception 'Capacity write bypass';exception when insufficient_privilege then null;end;
 begin perform public.reserve_open_house(current_setting('openhouse.test_event')::uuid,'55667788-0000-4000-8000-000000000080',0,3,'reserve',true);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
do $$ begin
 if exists(select 1 from public.open_house_rsvps) then raise exception 'Other prospect RSVP disclosure';end if;
 begin perform public.reserve_open_house(current_setting('openhouse.test_event')::uuid,gen_random_uuid(),0,2,'reserve',true);raise exception 'Capacity exceeded';exception when unique_violation then null;end;
 begin perform public.reserve_open_house(current_setting('openhouse.test_event')::uuid,gen_random_uuid(),0,1,'reserve',false);raise exception 'No consent accepted';exception when invalid_parameter_value then null;end;
 begin perform public.reserve_open_house(current_setting('openhouse.test_event')::uuid,gen_random_uuid(),0,null,'cancel',null);raise exception 'Other prospect cancel accepted';exception when insufficient_privilege then null;end;
end $$;
select public.reserve_open_house(current_setting('openhouse.test_event')::uuid,gen_random_uuid(),0,1,'reserve',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin begin perform public.reserve_open_house(current_setting('openhouse.test_event')::uuid,gen_random_uuid(),0,1,'reserve',true);raise exception 'Unverified reservation accepted';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin if exists(select 1 from public.open_house_rsvps) then raise exception 'Foreign organization RSVP disclosure';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ begin if (select sum(party_size) from public.open_house_rsvps)<>3 then raise exception 'Organization reservation read missing';end if;end $$;
select public.author_open_house_event('cancel',gen_random_uuid(),current_setting('openhouse.test_event')::uuid,1,null,null,null,null,null,'Fixture event cancelled by host',null);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin begin perform public.reserve_open_house(current_setting('openhouse.test_event')::uuid,gen_random_uuid(),1,1,'reserve',true);raise exception 'Cancelled event RSVP accepted';exception when insufficient_privilege then null;end;end $$;
select public.reserve_open_house(current_setting('openhouse.test_event')::uuid,gen_random_uuid(),1,null,'cancel',null);
reset role;
update public.open_house_events set title='Later public title' where id=current_setting('openhouse.test_event')::uuid;
do $$ begin
 begin update public.open_house_rsvps set title_snapshot='Forged history';raise exception 'History could be rewritten';exception when invalid_parameter_value then null;end;
 begin update public.open_house_rsvps set user_id='55667788-0000-4000-8000-000000000020';raise exception 'Reservation identity could be rebound';exception when invalid_parameter_value then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin
 if not exists(select 1 from public.open_house_rsvps where title_snapshot='RSVP fixture event' and area_snapshot='Kingston' and starts_at_snapshot=now()+interval '2 days' and ends_at_snapshot=now()+interval '2 days 1 hour') then raise exception 'Original event snapshot lost after cancellation';end if;
 if exists(select 1 from public.open_house_events where id=current_setting('openhouse.test_event')::uuid) then raise exception 'Cancelled event unexpectedly public';end if;
end $$;
reset role;
set local role anon;
do $$ begin begin perform 1 from public.open_house_rsvps;raise exception 'Public reservation identities disclosed';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
