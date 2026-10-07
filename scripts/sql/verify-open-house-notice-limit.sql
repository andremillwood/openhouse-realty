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
select set_config('openhouse.limit_event',public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Notice mutation limit fixture',now()+interval '2 days',now()+interval '2 days 1 hour',12,null,true)->>'event_id',true);
select public.reserve_open_house(current_setting('openhouse.limit_event')::uuid,gen_random_uuid(),0,1,'reserve',true);
do $$ begin
 for i in 1..29 loop perform public.reserve_open_house(current_setting('openhouse.limit_event')::uuid,gen_random_uuid(),i,1,'reserve',true);end loop;
 begin perform public.reserve_open_house(current_setting('openhouse.limit_event')::uuid,gen_random_uuid(),30,1,'reserve',true);raise exception 'Unlimited RSVP update notices accepted';exception when invalid_parameter_value then null;end;
 perform public.reserve_open_house(current_setting('openhouse.limit_event')::uuid,gen_random_uuid(),30,null,'cancel',null);
 if not exists(select 1 from public.open_house_rsvps where event_id=current_setting('openhouse.limit_event')::uuid and status='cancelled' and version=31) then raise exception 'Cancellation blocked by daily notice limit';end if;
end $$;
reset role;
rollback;
