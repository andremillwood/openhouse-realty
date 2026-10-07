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
insert into public.properties(id,organization_id,name) values ('55667788-0000-4000-8000-000000000031','55667788-0000-4000-8000-000000000006','Resource fixture');
insert into public.units(id,property_id,unit_label) values ('55667788-0000-4000-8000-000000000032','55667788-0000-4000-8000-000000000031','A'),('55667788-0000-4000-8000-000000000033','55667788-0000-4000-8000-000000000031','B');
update public.listings set property_id='55667788-0000-4000-8000-000000000031',unit_id='55667788-0000-4000-8000-000000000032' where id in ('55667788-0000-4000-8000-000000000008','55667788-0000-4000-8000-000000000009');
update public.listings set property_id='55667788-0000-4000-8000-000000000031',unit_id='55667788-0000-4000-8000-000000000033' where id='55667788-0000-4000-8000-000000000051';
update public.listings set property_id='55667788-0000-4000-8000-000000000031' where id='55667788-0000-4000-8000-000000000052';
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
set local role authenticated;
select public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Unit A open house',now()+interval '2 days',now()+interval '2 days 2 hours',12,null,true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
do $$ begin
 begin perform public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000009','Duplicate unit event',now()+interval '2 days',now()+interval '2 days 1 hour',12,null,true);raise exception 'Duplicate unit event accepted';exception when unique_violation then null;end;
 begin perform public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000009',now()+interval '2 days',now()+interval '2 days 1 hour');raise exception 'Duplicate unit viewing accepted';exception when unique_violation then null;end;
 begin perform public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000052','Whole property event',now()+interval '2 days',now()+interval '2 days 1 hour',12,null,true);raise exception 'Whole property overlap accepted';exception when unique_violation then null;end;
end $$;
select public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000051',now()+interval '2 days',now()+interval '2 days 1 hour');
select public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000009',now()+interval '4 days',now()+interval '4 days 1 hour');
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.manage_viewing_slot('create',gen_random_uuid(),null,'55667788-0000-4000-8000-000000000008',now()+interval '4 days',now()+interval '4 days 1 hour');raise exception 'Duplicate unit slots accepted';exception when unique_violation then null;end;
 begin perform public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Event over viewing',now()+interval '4 days',now()+interval '4 days 1 hour',12,null,true);raise exception 'Event over duplicate unit viewing accepted';exception when unique_violation then null;end;
end $$;
reset role;
do $$ begin
 begin update public.listings set unit_id='55667788-0000-4000-8000-000000000033' where id='55667788-0000-4000-8000-000000000008';raise exception 'Scheduled open house resource moved';exception when unique_violation then null;end;
 begin update public.listings set unit_id=null where id='55667788-0000-4000-8000-000000000051';raise exception 'Scheduled viewing resource moved';exception when unique_violation then null;end;
end $$;
update public.open_house_events set status='cancelled';
update public.viewing_slots set state='closed';
update public.listings set unit_id=null where id='55667788-0000-4000-8000-000000000008';
rollback;
