begin;
insert into auth.users(id,email,email_confirmed_at) values
('44556600-0000-4000-8000-000000000001','owner-admin@example.invalid',now()),
('44556600-0000-4000-8000-000000000002','approved-owner@example.invalid',now()),
('44556600-0000-4000-8000-000000000003','owner-manager@example.invalid',now()),
('44556600-0000-4000-8000-000000000004','other-owner@example.invalid',now()),
('44556600-0000-4000-8000-000000000005','unverified-owner@example.invalid',null),
('44556600-0000-4000-8000-000000000006','foreign-owner-admin@example.invalid',now());
insert into public.organizations(id,name) values('44556600-0000-4000-8000-000000000010','Owner fixture'),('44556600-0000-4000-8000-000000000011','Foreign owner fixture');
insert into public.staff_accounts(user_id,organization_id,role) values
('44556600-0000-4000-8000-000000000001','44556600-0000-4000-8000-000000000010','admin'),
('44556600-0000-4000-8000-000000000003','44556600-0000-4000-8000-000000000010','manager'),
('44556600-0000-4000-8000-000000000006','44556600-0000-4000-8000-000000000011','admin');
insert into public.properties(id,organization_id,name) values
('44556600-0000-4000-8000-000000000020','44556600-0000-4000-8000-000000000010','Approved owner property'),
('44556600-0000-4000-8000-000000000021','44556600-0000-4000-8000-000000000011','Foreign owner property');
insert into public.staff_accounts(user_id,organization_id,role) values('44556600-0000-4000-8000-000000000002','44556600-0000-4000-8000-000000000010','finance');
insert into auth.users(id,email,email_confirmed_at) values
('44556600-0000-4000-8000-000000000007','staff-decline@example.invalid',now()),
('44556600-0000-4000-8000-000000000008','staff-expired@example.invalid',now()),
('44556600-0000-4000-8000-000000000009','staff-revoked@example.invalid',now()),
('44556600-0000-4000-8000-000000000012','staff-stale-admin@example.invalid',now()),
('44556600-0000-4000-8000-000000000014','second-admin@example.invalid',now());
insert into public.staff_accounts(user_id,organization_id,role) values('44556600-0000-4000-8000-000000000014','44556600-0000-4000-8000-000000000010','admin');

select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.invite',public.manage_staff_invitation('44556600-0000-4000-8000-000000000060','create',null,0,' OTHER-OWNER@example.invalid ','finance','Private administrator approval rationale',true)->>'id',true);
select public.manage_staff_invitation('44556600-0000-4000-8000-000000000060','create',null,0,'other-owner@example.invalid','finance','Private administrator approval rationale',true);
do $$ declare result jsonb;begin
 result:=public.staff_notification_delivery_monitor('all','staff_invitation','all',1);
 if (result->>'total')::integer<>1 or result->'rows'->0->>'family'<>'staff_invitation' then raise exception 'Administrator invitation monitor wrong';end if;
 begin perform public.claim_transactional_notifications('sender@example.invalid','business@example.invalid','https://approved.example.invalid');raise exception 'Administrator claimed jobs';exception when insufficient_privilege then null;end;
 begin perform 1 from private.notification_outbox;raise exception 'Administrator saw outbox directly';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
do $$ declare result jsonb;begin
 result:=public.staff_notification_delivery_monitor('all','all','all',1);
 if (result->>'total')::integer<>0 or result->'counts'<>'{}'::jsonb or result->'delivery_counts'<>'{}'::jsonb then raise exception 'Manager invitation/counts exposed';end if;
 if (public.staff_notification_monitor('all','staff_invitation',1)->>'total')::integer<>0 then raise exception 'Legacy monitor exposed invitation';end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin if (public.staff_notification_delivery_monitor('all','staff_invitation','all',1)->>'total')::integer<>0 then raise exception 'Foreign invitation monitor exposed';end if;end $$;
reset role;
do $$ begin
 if(select count(*) from private.notification_outbox where staff_invitation_id=current_setting('openhouse.invite')::uuid)<>1 then raise exception 'Invitation retry duplicated email';end if;
 if not exists(select 1 from private.notification_outbox where staff_invitation_id=current_setting('openhouse.invite')::uuid and organization_id='44556600-0000-4000-8000-000000000010' and recipient='other-owner@example.invalid' and audience='staff' and text_snapshot not like '%Private administrator approval rationale%' and action_path='/account/invitations/'||current_setting('openhouse.invite')) then raise exception 'Invitation payload authority/private reason wrong';end if;
end $$;
set local role service_role;
select public.claim_enquiry_notifications('legacy@example.invalid','business@example.invalid');
do $$ begin if exists(select 1 from private.notification_outbox where staff_invitation_id=current_setting('openhouse.invite')::uuid and state<>'pending') then raise exception 'Legacy worker claimed invitation without canonical link';end if;end $$;
select public.claim_transactional_notifications('sender@example.invalid','business@example.invalid','https://approved.example.invalid');
select set_config('openhouse.outbox',(select id::text from private.notification_outbox where staff_invitation_id=current_setting('openhouse.invite')::uuid),true);
select set_config('openhouse.token',(select lease_token::text from private.notification_outbox where id=current_setting('openhouse.outbox')::uuid),true);
select set_config('openhouse.payload',(select text_snapshot from private.notification_outbox where id=current_setting('openhouse.outbox')::uuid),true);
do $$ begin
 if not public.notification_attempt_current(current_setting('openhouse.outbox')::uuid,current_setting('openhouse.token')::uuid) then raise exception 'Current invitation attempt denied';end if;
 if public.notification_attempt_current(current_setting('openhouse.outbox')::uuid,gen_random_uuid()) then raise exception 'Wrong invitation lease authorized';end if;
 if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.outbox')::uuid and recipient='other-owner@example.invalid' and sender='sender@example.invalid' and text_snapshot like '%https://approved.example.invalid/account/invitations/%') then raise exception 'Canonical invitation snapshot wrong';end if;
 if not public.complete_enquiry_notification(current_setting('openhouse.outbox')::uuid,current_setting('openhouse.token')::uuid,null,false) then raise exception 'Retry not scheduled';end if;
end $$;
update private.notification_outbox set available_at=now() where id=current_setting('openhouse.outbox')::uuid;
select public.claim_transactional_notifications('changed@example.invalid','changed-business@example.invalid','https://changed.example.invalid');
select set_config('openhouse.token',(select lease_token::text from private.notification_outbox where id=current_setting('openhouse.outbox')::uuid),true);
do $$ begin if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.outbox')::uuid and recipient='other-owner@example.invalid' and sender='sender@example.invalid' and text_snapshot=current_setting('openhouse.payload') and attempts=2) then raise exception 'Invitation retry payload changed';end if;end $$;
reset role;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000014',true);
set local role authenticated;
select public.manage_staff_invitation(gen_random_uuid(),'revoke',current_setting('openhouse.invite')::uuid,1,null,null,'Invitation approval withdrawn',true);
reset role;
set local role service_role;
do $$ begin
 if public.notification_attempt_current(current_setting('openhouse.outbox')::uuid,current_setting('openhouse.token')::uuid) then raise exception 'Revoked invitation attempt authorized';end if;
 if public.complete_enquiry_notification(current_setting('openhouse.outbox')::uuid,current_setting('openhouse.token')::uuid,'fixture-only',true) then raise exception 'Revoked invitation completion accepted';end if;
 if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.outbox')::uuid and state='superseded' and lease_token is null) then raise exception 'Revoked invitation email not superseded';end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
insert into public.staff_invitations(id,organization_id,created_by,invite_email,role,expires_at) values('44556600-0000-4000-8000-000000000080','44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000001','staff-expired@example.invalid','manager',now()-interval '1 hour');
set local role service_role;
select public.claim_transactional_notifications('sender@example.invalid','business@example.invalid','https://approved.example.invalid');
do $$ begin if not exists(select 1 from private.notification_outbox where staff_invitation_id='44556600-0000-4000-8000-000000000080' and state='superseded' and attempts=0) then raise exception 'Expired invitation was claimed';end if;end $$;
reset role;
set local role authenticated;
select set_config('openhouse.stale_invite',public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'staff-stale-admin@example.invalid','manager','Approved manager invitation',true)->>'id',true);
reset role;
set local role service_role;
select public.claim_transactional_notifications('sender@example.invalid','business@example.invalid','https://approved.example.invalid');
select set_config('openhouse.stale_outbox',(select id::text from private.notification_outbox where staff_invitation_id=current_setting('openhouse.stale_invite')::uuid),true);
select set_config('openhouse.stale_token',(select lease_token::text from private.notification_outbox where id=current_setting('openhouse.stale_outbox')::uuid),true);
reset role;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000014',true);
set local role authenticated;
select public.manage_staff_membership(gen_random_uuid(),'owner-admin@example.invalid',null,(select membership_revision from public.staff_accounts where user_id='44556600-0000-4000-8000-000000000001'),'Inviting administrator revoked',true);
reset role;
set local role service_role;
do $$ begin if public.notification_attempt_current(current_setting('openhouse.stale_outbox')::uuid,current_setting('openhouse.stale_token')::uuid) then raise exception 'Stale inviter attempt authorized';end if;end $$;
select public.claim_transactional_notifications('sender@example.invalid','business@example.invalid','https://approved.example.invalid');
do $$ begin if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.stale_outbox')::uuid and state='superseded' and lease_token is null) then raise exception 'Stale inviter notice not superseded';end if;end $$;
reset role;

select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000014',true);
set local role authenticated;
select set_config('openhouse.accept_invite',public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'staff-decline@example.invalid','manager','Approved accepted invitation fixture',true)->>'id',true);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000007',true);
select public.manage_staff_invitation('44556600-0000-4000-8000-000000000090','accept',current_setting('openhouse.accept_invite')::uuid,1,null,null,'Accept manager invitation fixture',true);
reset role;
do $$ begin if not exists(select 1 from private.notification_outbox where staff_invitation_id=current_setting('openhouse.accept_invite')::uuid and state='superseded' and attempts=0) then raise exception 'Accepted invitation notice not superseded';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000014',true);
set local role authenticated;
select public.manage_staff_membership(gen_random_uuid(),'staff-decline@example.invalid',null,(select membership_revision from public.staff_accounts where user_id='44556600-0000-4000-8000-000000000007'),'Revoke accepted invitation membership',true);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000007',true);
select public.manage_staff_invitation('44556600-0000-4000-8000-000000000090','accept',current_setting('openhouse.accept_invite')::uuid,1,null,null,'Accept manager invitation fixture',true);
reset role;
do $$ begin if exists(select 1 from public.staff_accounts where user_id='44556600-0000-4000-8000-000000000007') or (select count(*) from public.staff_membership_changes where invitation_id=current_setting('openhouse.accept_invite')::uuid)<>1 then raise exception 'Accepted retry regranted revoked membership';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000014',true);
set local role authenticated;
select set_config('openhouse.decline_invite',public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'staff-revoked@example.invalid','manager','Approved declined invitation fixture',true)->>'id',true);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000009',true);
select public.manage_staff_invitation(gen_random_uuid(),'decline',current_setting('openhouse.decline_invite')::uuid,1,null,null,'Decline manager invitation fixture',true);
reset role;
do $$ begin if not exists(select 1 from private.notification_outbox where staff_invitation_id=current_setting('openhouse.decline_invite')::uuid and state='superseded' and attempts=0) then raise exception 'Declined invitation notice not superseded';end if;end $$;
rollback;
