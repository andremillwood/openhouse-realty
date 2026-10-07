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
do $$ declare invitation uuid:=current_setting('openhouse.test_cosigner')::uuid;begin
 if invitation<>public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000013','other@example.invalid',true) or (select count(*) from public.application_cosigner_events)<>1 then raise exception 'Invitation retry duplicated';end if;
 begin perform public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'applicant@example.invalid',true);raise exception 'Self-invite allowed';exception when invalid_parameter_value then null;end;
 begin perform public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'other@example.invalid',false);raise exception 'Unconsented sharing allowed';exception when invalid_parameter_value then null;end;
 begin perform public.respond_application_cosigner(invitation,gen_random_uuid(),1,'accept',true);raise exception 'Applicant impersonated recipient';exception when insufficient_privilege then null;end;
 begin update public.application_cosigners set state='accepted';raise exception 'Direct consent write allowed';exception when insufficient_privilege then null;end;
 perform public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'another@example.invalid',true);
 begin perform public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'third@example.invalid',true);raise exception 'Active invitation cap bypassed';exception when raise_exception then if sqlerrm='Active invitation cap bypassed' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.application_cosigners) or exists(select 1 from public.application_cosigner_events) or public.cosigner_invitation_active(current_setting('openhouse.test_cosigner')::uuid) then raise exception 'Foreign organization invitation disclosure';end if;
 begin perform public.respond_application_cosigner(current_setting('openhouse.test_cosigner')::uuid,gen_random_uuid(),1,'accept',true);raise exception 'Foreign account consent accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin if exists(select 1 from public.application_cosigners) or exists(select 1 from public.application_cosigner_events) then raise exception 'Unverified account invitation disclosure';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ declare invitation uuid:=current_setting('openhouse.test_cosigner')::uuid;result jsonb;begin
 if (select count(*) from public.application_cosigners)<>1 or (select count(*) from public.application_cosigner_events)<>1 or exists(select 1 from public.rental_applications) or exists(select 1 from public.application_documents) then raise exception 'Recipient scope includes unrelated private data';end if;
 if not public.cosigner_invitation_active(invitation) then raise exception 'Recipient cannot act on invitation';end if;
 begin perform public.respond_application_cosigner(invitation,gen_random_uuid(),1,'accept',false);raise exception 'Missing consent accepted';exception when invalid_parameter_value then null;end;
 result:=public.respond_application_cosigner(invitation,'55667788-0000-4000-8000-000000000014',1,'accept',true);
 if result->>'state'<>'accepted' or (result->>'version')::integer<>2 then raise exception 'Consent/version missing';end if;
 perform public.respond_application_cosigner(invitation,'55667788-0000-4000-8000-000000000014',1,'accept',true);
 if (select count(*) from public.application_cosigner_events)<>2 or not exists(select 1 from public.application_cosigners where recipient_user_id=auth.uid() and consent_version=1 and consented_at is not null) then raise exception 'Consent retry/binding failed';end if;
 begin perform public.respond_application_cosigner(invitation,gen_random_uuid(),1,'withdraw',false);raise exception 'Stale withdrawal accepted';exception when serialization_failure then null;end;
end $$;
reset role;
update auth.users set email='changed@example.invalid' where id='55667788-0000-4000-8000-000000000002';
update public.rental_applications set status='approved' where id=current_setting('openhouse.test_application')::uuid;
set local role authenticated;
select public.respond_application_cosigner(current_setting('openhouse.test_cosigner')::uuid,'55667788-0000-4000-8000-000000000015',2,'withdraw',false);
do $$ begin if (select state from public.application_cosigners where id=current_setting('openhouse.test_cosigner')::uuid)<>'withdrawn' then raise exception 'Bound recipient lost withdrawal after email change';end if;end $$;
reset role;
do $$ begin if (select status from public.rental_applications where id=current_setting('openhouse.test_application')::uuid)<>'under_review' then raise exception 'Approval not invalidated by consent withdrawal';end if;end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
select set_config('openhouse.test_expired',public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000016','changed@example.invalid',true)::text,true);
reset role;
update public.application_cosigners set expires_at=now()-interval '1 minute' where id=current_setting('openhouse.test_expired')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin
 if public.cosigner_invitation_active(current_setting('openhouse.test_expired')::uuid) then raise exception 'Expired invitation active';end if;
 begin perform public.respond_application_cosigner(current_setting('openhouse.test_expired')::uuid,gen_random_uuid(),1,'accept',true);raise exception 'Expired consent accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
select public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,'55667788-0000-4000-8000-000000000017','changed@example.invalid',true);
do $$ begin if not exists(select 1 from public.application_cosigner_events where cosigner_id=current_setting('openhouse.test_expired')::uuid and event_name='expired') then raise exception 'Expiry audit absent';end if;end $$;
do $$ declare invitation uuid;begin
 select id into invitation from public.application_cosigners where request_id='55667788-0000-4000-8000-000000000017';
 perform public.respond_application_cosigner(invitation,gen_random_uuid(),1,'revoke',false);
 invitation:=public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'changed@example.invalid',true);
 perform set_config('openhouse.test_decline',invitation::text,true);
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.respond_application_cosigner(current_setting('openhouse.test_decline')::uuid,gen_random_uuid(),1,'decline',false);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000001',true);
do $$ begin
 begin perform public.invite_application_cosigner(current_setting('openhouse.test_application')::uuid,gen_random_uuid(),'changed@example.invalid',true);raise exception 'Daily cap bypassed';exception when raise_exception then if sqlerrm='Daily cap bypassed' then raise;end if;end;
end $$;
rollback;
