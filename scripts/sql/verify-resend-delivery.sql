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
set local role service_role;
select set_config('openhouse.test_event_time',(now()-interval '2 minutes')::text,true);
select public.record_resend_delivery_event('msg_delivered_fixture','55667788-0000-4000-8000-000000000090','email.delivered',current_setting('openhouse.test_event_time')::timestamptz,repeat('a',64));
do $$ begin if not exists(select 1 from private.resend_delivery_events where event_id='msg_delivered_fixture' and outbox_id is null) then raise exception 'Early webhook not retained';end if;end $$;
select public.claim_transactional_notifications('sender@example.invalid','business@example.invalid','https://approved.example.invalid');
select set_config('openhouse.test_outbox',(select id::text from private.notification_outbox where cosigner_id=current_setting('openhouse.test_cosigner')::uuid),true);
select set_config('openhouse.test_token',(select lease_token::text from private.notification_outbox where id=current_setting('openhouse.test_outbox')::uuid),true);
select public.complete_enquiry_notification(current_setting('openhouse.test_outbox')::uuid,current_setting('openhouse.test_token')::uuid,'55667788-0000-4000-8000-000000000090',true);
select public.reconcile_resend_delivery_events();
do $$ begin
 if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.test_outbox')::uuid and state='sent' and delivery_state='delivered') or not exists(select 1 from private.resend_delivery_events where outbox_id=current_setting('openhouse.test_outbox')::uuid) then raise exception 'Early event not reconciled after provider ID persistence';end if;
end $$;
select public.record_resend_delivery_event('msg_delivered_fixture','55667788-0000-4000-8000-000000000090','email.delivered',current_setting('openhouse.test_event_time')::timestamptz,repeat('a',64));
do $$ begin
 if (select count(*) from private.resend_delivery_events where event_id='msg_delivered_fixture')<>1 then raise exception 'Replay duplicated';end if;
 begin perform public.record_resend_delivery_event('msg_delivered_fixture','55667788-0000-4000-8000-000000000090','email.delivered',current_setting('openhouse.test_event_time')::timestamptz,repeat('b',64));raise exception 'Changed replay accepted';exception when invalid_parameter_value then null;end;
end $$;
select public.record_resend_delivery_event('msg_older_sent','55667788-0000-4000-8000-000000000090','email.sent',now()-interval '5 minutes',repeat('c',64));
do $$ begin if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.test_outbox')::uuid and delivery_state='delivered') then raise exception 'Older send regressed delivered';end if;end $$;
select public.record_resend_delivery_event('msg_bounced','55667788-0000-4000-8000-000000000090','email.bounced',now()-interval '1 minute',repeat('d',64));
select public.record_resend_delivery_event('msg_later_positive','55667788-0000-4000-8000-000000000090','email.delivered',now(),repeat('e',64));
do $$ begin if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.test_outbox')::uuid and delivery_state='bounced' and state='sent') then raise exception 'Bounce evidence erased or send job retried';end if;end $$;
select public.record_resend_delivery_event('msg_complained','55667788-0000-4000-8000-000000000090','email.complained',now(),repeat('f',64));
select public.record_resend_delivery_event('msg_other_project_message','55667788-0000-4000-8000-000000000091','email.failed',now(),repeat('a',64));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ declare result jsonb;begin
 result:=public.staff_notification_delivery_monitor('all','cosigner','complained',1);
 if (result->>'total')::integer<>1 or result->'rows'->0->>'delivery_state'<>'complained' or (result->'delivery_counts'->>'complained')::integer<>1 then raise exception 'Scoped delivery monitor missing complaint';end if;
 if result->'rows'->0 ?| array['payload_sha256','provider_id','recipient','text_snapshot'] then raise exception 'Webhook private metadata exposed';end if;
 begin perform public.record_resend_delivery_event('msg_staff_spoof','55667788-0000-4000-8000-000000000090','email.delivered',now(),repeat('a',64));raise exception 'Staff spoofed provider evidence';exception when insufficient_privilege then null;end;
 begin perform public.reconcile_resend_delivery_events();raise exception 'Staff ran trusted reconciliation';exception when insufficient_privilege then null;end;
 begin perform 1 from private.resend_delivery_events;raise exception 'Staff saw private provider metadata';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin if (public.staff_notification_delivery_monitor('all','all','all',1)->>'total')::integer<>0 then raise exception 'Foreign delivery monitor leak';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin begin perform public.staff_notification_delivery_monitor('all','all','all',1);raise exception 'Unverified delivery monitoring';exception when insufficient_privilege then null;end;end $$;
rollback;
