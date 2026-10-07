begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('22334455-0000-4000-8000-000000000001','prospect-test@example.invalid',now()),
 ('22334455-0000-4000-8000-000000000002','other-test@example.invalid',now()),
 ('22334455-0000-4000-8000-000000000003','staff-test@example.invalid',now());
insert into public.organizations(id,name) values ('22334455-0000-4000-8000-000000000004','Enquiry test organization');
insert into public.staff_accounts(user_id,organization_id,role) values ('22334455-0000-4000-8000-000000000003','22334455-0000-4000-8000-000000000004','realtor');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values ('22334455-0000-4000-8000-000000000005','22334455-0000-4000-8000-000000000004','Enquiry fixture','Test area','rent','house','published',100,'An approved-length fixture description for permission tests.','https://example.invalid/fixture.jpg');
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000001',true);
set local role authenticated;
select public.submit_enquiry('22334455-0000-4000-8000-000000000006','22334455-0000-4000-8000-000000000005',null,'Test prospect','','Please arrange a viewing for this property.',true);
select public.submit_enquiry('22334455-0000-4000-8000-000000000006','22334455-0000-4000-8000-000000000005',null,'Test prospect','','Please arrange a viewing for this property.',true);
do $$ begin
 if (select count(*) from public.enquiries) <> 1 then raise exception 'Duplicate enquiry accepted'; end if;
 if (select contact_email from public.enquiries limit 1) <> 'prospect-test@example.invalid' then raise exception 'Verified contact identity failure'; end if;
 begin
  update public.enquiries set status='contacted';
  if found then raise exception 'Prospect status update accepted'; end if;
 exception when insufficient_privilege then null; end;
 begin
  perform public.submit_enquiry('22334455-0000-4000-8000-000000000007','22334455-0000-4000-8000-000000000005',null,'Test prospect','','Please arrange a viewing for this property.',false);
  raise exception 'Missing consent accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.submit_enquiry('22334455-0000-4000-8000-000000000006','22334455-0000-4000-8000-000000000005',null,'Test prospect','','An altered message with reused request ID.',true);
  raise exception 'Idempotency payload conflict accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.claim_enquiry_notifications('sender@example.invalid','recipient@example.invalid');
  raise exception 'Browser worker access accepted';
 exception when insufficient_privilege then null; end;
end $$;
do $$ declare i integer; begin
 for i in 7..10 loop
  perform public.submit_enquiry(('22334455-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'22334455-0000-4000-8000-000000000005',null,'Test prospect','','Please arrange a viewing for this property.',true);
 end loop;
 begin
  perform public.submit_enquiry('22334455-0000-4000-8000-000000000011','22334455-0000-4000-8000-000000000005',null,'Test prospect','','Please arrange a viewing for this property.',true);
  raise exception 'Rate limit accepted sixth enquiry' using errcode='XX000';
 exception when raise_exception then null; end;
end $$;
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.enquiries) then raise exception 'Cross-user enquiry read accepted'; end if; end $$;
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000003',true);
update public.enquiries set status='contacted';
update public.listings set title='Changed after submission' where id='22334455-0000-4000-8000-000000000005';
do $$ begin
 if (select count(*) from public.enquiries)<>5 then raise exception 'Staff cannot read organization enquiry'; end if;
 if not exists(select 1 from public.enquiry_events where event_name='status_changed' and new_status='contacted') then raise exception 'Missing status audit'; end if;
end $$;
reset role;
set local role service_role;
do $$ declare job record; other_claims integer; ok boolean; begin
 select * into job from public.claim_enquiry_notifications('sender@example.invalid','recipient@example.invalid') where contact_email='prospect-test@example.invalid';
 if job.outbox_id is null then raise exception 'Outbox job missing'; end if;
 if job.target_title<>'Enquiry fixture' or job.recipient<>'recipient@example.invalid' then raise exception 'Notification snapshot failure'; end if;
 select count(*) into other_claims from public.claim_enquiry_notifications('sender@example.invalid','recipient@example.invalid');
 if other_claims<>0 then raise exception 'Concurrent job claim accepted'; end if;
 select public.complete_enquiry_notification(job.outbox_id,'22334455-0000-4000-8000-000000000099',null,true) into ok;
 if ok then raise exception 'Wrong lease completion accepted'; end if;
 select public.complete_enquiry_notification(job.outbox_id,job.lease_token,'fixture-provider-id',true) into ok;
 if not ok then raise exception 'Valid lease completion failed'; end if;
 if not exists(select 1 from private.notification_outbox where id=job.outbox_id and state='sent') then raise exception 'Accepted notification not stored'; end if;
end $$;
reset role;
rollback;
select 'PASS: enquiry idempotency/consent/identity/isolation/rate limit, staff audit, restricted outbox, exclusive notification claims, lease ownership and stable title snapshots. Fixtures rolled back; no email sent.' as verification;
