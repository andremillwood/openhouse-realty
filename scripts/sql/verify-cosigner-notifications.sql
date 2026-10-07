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
do $$ begin
 if (select count(*) from private.notification_outbox where cosigner_id=current_setting('openhouse.test_cosigner')::uuid)<>1 then raise exception 'Invitation email not queued atomically';end if;
 if not exists(select 1 from private.notification_outbox where cosigner_id=current_setting('openhouse.test_cosigner')::uuid and recipient='other@example.invalid' and action_path='/cosigners/'||current_setting('openhouse.test_cosigner') and text_snapshot not like '%rental application.%') then raise exception 'Limited invitation payload mismatch';end if;
end $$;
set local role authenticated;
select public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000013','other@example.invalid',true);
do $$ begin
 begin perform public.claim_transactional_notifications('sender@example.invalid','business@example.invalid','https://approved.example.invalid');raise exception 'Applicant claimed private jobs';exception when insufficient_privilege then null;end;
 begin perform public.notification_attempt_current(gen_random_uuid(),gen_random_uuid());raise exception 'Applicant accessed send authorization';exception when insufficient_privilege then null;end;
 begin perform 1 from private.notification_outbox;raise exception 'Applicant saw recipient outbox';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role service_role;
select public.claim_enquiry_notifications('legacy@example.invalid','business@example.invalid');
do $$ begin if exists(select 1 from private.notification_outbox where cosigner_id=current_setting('openhouse.test_cosigner')::uuid and state<>'pending') then raise exception 'Legacy worker claimed linkless invite';end if;end $$;
select public.claim_transactional_notifications('sender@example.invalid','business@example.invalid','https://approved.example.invalid');
select set_config('openhouse.test_outbox',(select id::text from private.notification_outbox where cosigner_id=current_setting('openhouse.test_cosigner')::uuid),true);
select set_config('openhouse.test_token',(select lease_token::text from private.notification_outbox where id=current_setting('openhouse.test_outbox')::uuid),true);
select set_config('openhouse.test_payload',(select text_snapshot from private.notification_outbox where id=current_setting('openhouse.test_outbox')::uuid),true);
do $$ begin
 if not public.notification_attempt_current(current_setting('openhouse.test_outbox')::uuid,current_setting('openhouse.test_token')::uuid) then raise exception 'Valid invite attempt denied';end if;
 if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.test_outbox')::uuid and recipient='other@example.invalid' and sender='sender@example.invalid' and text_snapshot like '%https://approved.example.invalid/cosigners/%') then raise exception 'Canonical invitation snapshot missing';end if;
 if public.notification_attempt_current(current_setting('openhouse.test_outbox')::uuid,gen_random_uuid()) then raise exception 'Incorrect lease token authorized';end if;
 if not public.complete_enquiry_notification(current_setting('openhouse.test_outbox')::uuid,current_setting('openhouse.test_token')::uuid,null,false) then raise exception 'Invitation retry not scheduled';end if;
end $$;
update private.notification_outbox set available_at=now() where id=current_setting('openhouse.test_outbox')::uuid;
select public.claim_transactional_notifications('changed@example.invalid','otherbusiness@example.invalid','https://changed.example.invalid');
select set_config('openhouse.test_token',(select lease_token::text from private.notification_outbox where id=current_setting('openhouse.test_outbox')::uuid),true);
do $$ begin if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.test_outbox')::uuid and sender='sender@example.invalid' and recipient='other@example.invalid' and text_snapshot=current_setting('openhouse.test_payload') and attempts=2) then raise exception 'Provider retry payload changed';end if;end $$;
reset role;
set local role authenticated;
select public.respond_application_cosigner(current_setting('openhouse.test_cosigner')::uuid,gen_random_uuid(),1,'revoke',false);
reset role;
set local role service_role;
do $$ begin
 if public.notification_attempt_current(current_setting('openhouse.test_outbox')::uuid,current_setting('openhouse.test_token')::uuid) then raise exception 'Revoked invite authorized for sending';end if;
 if public.complete_enquiry_notification(current_setting('openhouse.test_outbox')::uuid,current_setting('openhouse.test_token')::uuid,'test-only',true) then raise exception 'Revoked claim completion accepted';end if;
 if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.test_outbox')::uuid and state='superseded') then raise exception 'Revoked email not superseded';end if;
end $$;
reset role;
set local role authenticated;
select set_config('openhouse.test_expired',public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'expired@example.invalid',true)::text,true);
reset role;
update public.application_cosigners set expires_at=now()-interval '1 minute' where id=current_setting('openhouse.test_expired')::uuid;
set local role service_role;
select public.claim_transactional_notifications('sender@example.invalid','business@example.invalid','https://approved.example.invalid');
do $$ begin if not exists(select 1 from private.notification_outbox where cosigner_id=current_setting('openhouse.test_expired')::uuid and state='superseded' and attempts=0) then raise exception 'Expired email claimed';end if;end $$;
reset role;
set local role authenticated;
select set_config('openhouse.test_closed',public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'closed@example.invalid',true)::text,true);
select public.transition_rental_application(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),(select version from public.rental_applications where id=current_setting('openhouse.test_application')::uuid),'withdraw','Application no longer needed.');
reset role;
do $$ begin if not exists(select 1 from private.notification_outbox where cosigner_id=current_setting('openhouse.test_closed')::uuid and state='superseded') then raise exception 'Closed application invite remained queued';end if;end $$;
rollback;
