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
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.test_application',public.submit_rental_application('55667788-0000-4000-8000-000000000012','55667788-0000-4000-8000-000000000008',null,'Test Applicant','',2,(now() at time zone 'America/Jamaica')::date+30,'Please review my rental application.',true)::text,true);
select set_config('openhouse.test_cosigner',public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000013','OTHER@example.invalid',true)::text,true);
reset role;
do $$ begin if exists(select 1 from private.notification_outbox where organization_id is distinct from '55667788-0000-4000-8000-000000000006'::uuid) then raise exception 'Application/cosigner organization binding missing';end if;end $$;
with created as (
 insert into public.enquiries(user_id,organization_id,listing_id,request_id,contact_name,contact_email,message) select '55667788-0000-4000-8000-000000000001','55667788-0000-4000-8000-000000000006','55667788-0000-4000-8000-000000000008',gen_random_uuid(),'Monitor applicant','applicant@example.invalid','Private enquiry fixture message' from generate_series(1,32) returning id
) insert into private.notification_outbox(enquiry_id,organization_id,target_title) select id,'55667788-0000-4000-8000-000000000007','Enquiry monitor fixture' from created;
update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where id=(select id from private.notification_outbox where enquiry_id is not null limit 1);
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values('55667788-0000-4000-8000-000000000060','55667788-0000-4000-8000-000000000007','Foreign fixture','Kingston','rent','house','published',100000,'Approved foreign fixture description.','https://example.invalid/approved.jpg');
with created as (insert into public.enquiries(user_id,organization_id,listing_id,request_id,contact_name,contact_email,message) values('55667788-0000-4000-8000-000000000004','55667788-0000-4000-8000-000000000007','55667788-0000-4000-8000-000000000060',gen_random_uuid(),'Foreign applicant','foreign@example.invalid','Foreign private fixture message') returning id) insert into private.notification_outbox(enquiry_id,target_title) select id,'Foreign private fixture' from created;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ declare result jsonb;row jsonb;begin
 result:=public.staff_notification_monitor('all','all',1);
 if (result->>'total')::integer<>35 or (result->>'pages')::integer<>2 or jsonb_array_length(result->'rows')<>25 or (result->'counts'->>'failed')::integer<>1 then raise exception 'Monitor totals/state aggregation failed';end if;
 result:=public.staff_notification_monitor('all','all',99999);
 if (result->>'page')::integer<>2 or jsonb_array_length(result->'rows')<>10 then raise exception 'Monitor page clipping failed';end if;
 result:=public.staff_notification_monitor('all','enquiry',2);
 if (result->>'total')::integer<>32 or jsonb_array_length(result->'rows')<>7 then raise exception 'Family pagination failed';end if;
 result:=public.staff_notification_monitor('failed','all',1);
 if (result->>'total')::integer<>1 or result->'rows'->0->>'state'<>'failed' then raise exception 'Failed queue filter failed';end if;
 for row in select value from jsonb_array_elements(result->'rows') loop
 if row ?| array['text_snapshot','recipient','sender','lease_token','provider_id','contact_email'] then raise exception 'Sensitive worker payload exposed';end if;
 end loop;
 begin perform public.staff_notification_monitor('invalid','all',1);raise exception 'Invalid state allowed';exception when invalid_parameter_value then null;end;
 begin perform public.staff_notification_monitor('all','all',0);raise exception 'Invalid page allowed';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ declare result jsonb;begin result:=public.staff_notification_monitor('all','all',1);if (result->>'total')::integer<>1 or result->'rows'->0->>'target_title'<>'Foreign private fixture' then raise exception 'Organization monitor leak';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin begin perform public.staff_notification_monitor('all','all',1);raise exception 'Unverified staff monitored queue';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin begin perform public.staff_notification_monitor('all','all',1);raise exception 'Prospect monitored queue';exception when insufficient_privilege then null;end;end $$;
reset role;
set local role anon;
do $$ begin begin perform public.staff_notification_monitor('all','all',1);raise exception 'Anonymous monitored queue';exception when insufficient_privilege then null;end;end $$;
rollback;
