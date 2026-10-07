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
select set_config('openhouse.roster_event',public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Roster fixture',now()+interval '2 days',now()+interval '2 days 1 hour',50,null,true)->>'event_id',true);
reset role;
insert into auth.users(id,email,email_confirmed_at) select ('55667788-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'roster-'||i||'@example.invalid',now() from generate_series(100,127) i;
insert into public.open_house_rsvps(event_id,organization_id,user_id,party_size,status) select current_setting('openhouse.roster_event')::uuid,'55667788-0000-4000-8000-000000000006',('55667788-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,1,case when i=100 then 'cancelled' else 'going' end from generate_series(100,127) i;
set local role authenticated;
do $$ declare result jsonb;begin
 result:=public.open_house_staff_roster(current_setting('openhouse.roster_event')::uuid,'all',2);
 if (result->>'total')::int<>28 or (result->>'pages')::int<>2 or jsonb_array_length(result->'rows')<>3 or (result->>'reserved_places')::int<>27 or (result->>'cancelled_parties')::int<>1 then raise exception 'Roster pagination or capacity totals incorrect';end if;
 if result->'rows'->0->>'contact_email' is null or result->'rows'->0 ? 'user_id' then raise exception 'Verified contact missing or unneeded identity exposed';end if;
 result:=public.open_house_staff_roster(current_setting('openhouse.roster_event')::uuid,'cancelled',99);
 if (result->>'page')::int<>1 or (result->>'total')::int<>1 or jsonb_array_length(result->'rows')<>1 then raise exception 'Roster filter/clipping incorrect';end if;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin begin perform public.open_house_staff_roster(current_setting('openhouse.roster_event')::uuid,'all',1);raise exception 'Foreign staff contact disclosure';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin begin perform public.open_house_staff_roster(current_setting('openhouse.roster_event')::uuid,'all',1);raise exception 'Unverified staff contact disclosure';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin begin perform public.open_house_staff_roster(current_setting('openhouse.roster_event')::uuid,'all',1);raise exception 'Prospect contact disclosure';exception when insufficient_privilege then null;end;end $$;
reset role;
set local role anon;
do $$ begin begin perform public.open_house_staff_roster(current_setting('openhouse.roster_event')::uuid,'all',1);raise exception 'Anonymous contact disclosure';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
