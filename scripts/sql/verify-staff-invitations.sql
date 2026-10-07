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
select set_config('openhouse.invite',public.manage_staff_invitation('44556600-0000-4000-8000-000000000060','create',null,0,' OTHER-OWNER@example.invalid ','finance','Approved finance team invitation',true)::text,true);
do $$ declare r jsonb:=current_setting('openhouse.invite')::jsonb;begin
 if public.manage_staff_invitation('44556600-0000-4000-8000-000000000060','create',null,0,'other-owner@example.invalid','finance','Approved finance team invitation',true)<>r then raise exception 'Create retry changed';end if;
 begin perform public.manage_staff_invitation('44556600-0000-4000-8000-000000000060','create',null,0,'other-owner@example.invalid','admin','Approved finance team invitation',true);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'other-owner@example.invalid','finance','Duplicate team invitation',true);raise exception 'Duplicate pending invite allowed';exception when unique_violation then null;end;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'approved-owner@example.invalid','admin','Existing staff invitation',true);raise exception 'Existing member invite allowed';exception when insufficient_privilege then null;end;
 begin update public.staff_invitations set role='admin' where id=(r->>'id')::uuid;raise exception 'Client invitation edit allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('openhouse.unverified_invite',public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'unverified-owner@example.invalid','realtor','Approved realtor invitation',true)::text,true);
select set_config('openhouse.decline_invite',public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'staff-decline@example.invalid','manager','Approved manager invitation',true)::text,true);
select set_config('openhouse.revoked_invite',public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'staff-revoked@example.invalid','manager','Approved manager invitation',true)::text,true);
select set_config('openhouse.stale_invite',public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'staff-stale-admin@example.invalid','manager','Approved manager invitation',true)::text,true);
select public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'not-registered@example.invalid','realtor','Approved new account invitation',true);
select public.manage_staff_invitation(gen_random_uuid(),'revoke',(current_setting('openhouse.revoked_invite')::jsonb->>'id')::uuid,1,null,null,'Invitation approval withdrawn',true);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'other@example.invalid','admin','Manager invitation attempt',true);raise exception 'Manager created invite';exception when insufficient_privilege then null;end;
 if exists(select id from public.staff_invitations) then raise exception 'Manager saw administrator invitations';end if;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'accept',(current_setting('openhouse.invite')::jsonb->>'id')::uuid,1,null,null,'Accept other user invitation',true);raise exception 'Wrong email accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin if exists(select id from public.staff_invitations) then raise exception 'Foreign invitation exposed';end if; if public.staff_invitation_summary((current_setting('openhouse.invite')::jsonb->>'id')::uuid) is not null then raise exception 'Foreign summary exposed';end if;end $$;
select set_config('openhouse.foreign_invite',public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'other-owner@example.invalid','manager','Approved foreign invitation',true)::text,true);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000005',true);
do $$ begin
 if exists(select id from public.staff_invitations) then raise exception 'Unverified recipient read invite';end if;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'accept',(current_setting('openhouse.unverified_invite')::jsonb->>'id')::uuid,1,null,null,'Accept unverified invitation',true);raise exception 'Unverified recipient accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000004',true);
do $$ begin
 if public.staff_invitation_summary((current_setting('openhouse.invite')::jsonb->>'id')::uuid)->>'organization_name'<>'Owner fixture' or not (public.staff_invitation_summary((current_setting('openhouse.invite')::jsonb->>'id')::uuid)->>'can_accept')::boolean then raise exception 'Pending recipient summary wrong';end if;
 if public.staff_invitation_summary((current_setting('openhouse.invite')::jsonb->>'id')::uuid) ? 'created_by' or public.staff_invitation_summary((current_setting('openhouse.invite')::jsonb->>'id')::uuid) ? 'reason' then raise exception 'Private approval details exposed';end if;
 if (select count(id) from public.staff_invitations)<>2 then raise exception 'Email-bound recipient reads wrong';end if;
 if exists(select id from public.staff_invitation_events) then raise exception 'Recipient saw internal approval events';end if;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'accept',(current_setting('openhouse.invite')::jsonb->>'id')::uuid,1,null,null,'Accept without explicit consent',false);raise exception 'Consent not required';exception when invalid_parameter_value then null;end;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'accept',(current_setting('openhouse.invite')::jsonb->>'id')::uuid,2,null,null,'Accept stale invitation revision',true);raise exception 'Stale acceptance allowed';exception when serialization_failure then null;end;
end $$;
select set_config('openhouse.accepted',public.manage_staff_invitation('44556600-0000-4000-8000-000000000061','accept',(current_setting('openhouse.invite')::jsonb->>'id')::uuid,1,null,null,'I accept the approved finance role',true)::text,true);
do $$ begin
 if public.manage_staff_invitation('44556600-0000-4000-8000-000000000061','accept',(current_setting('openhouse.invite')::jsonb->>'id')::uuid,1,null,null,'I accept the approved finance role',true)<>current_setting('openhouse.accepted')::jsonb then raise exception 'Acceptance retry changed';end if;
 if not exists(select 1 from public.staff_accounts where user_id=auth.uid() and role='finance' and organization_id='44556600-0000-4000-8000-000000000010') then raise exception 'Invited role binding missing';end if;
 if exists(select id from public.staff_invitation_events) then raise exception 'Finance recipient saw administrator reasons';end if; if (public.staff_invitation_summary((current_setting('openhouse.foreign_invite')::jsonb->>'id')::uuid)->>'can_accept')::boolean then raise exception 'Existing membership summary offered acceptance';end if;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'accept',(current_setting('openhouse.foreign_invite')::jsonb->>'id')::uuid,1,null,null,'Accept conflicting organization invite',true);raise exception 'Membership silently overwritten';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000007',true);
select public.manage_staff_invitation(gen_random_uuid(),'decline',(current_setting('openhouse.decline_invite')::jsonb->>'id')::uuid,1,null,null,'I decline the approved manager role',true);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000009',true);
do $$ begin
 begin perform public.manage_staff_invitation(gen_random_uuid(),'accept',(current_setting('openhouse.revoked_invite')::jsonb->>'id')::uuid,2,null,null,'Accept revoked manager invitation',true);raise exception 'Revoked invitation accepted';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000014',true);
select public.manage_staff_membership(gen_random_uuid(),'owner-admin@example.invalid',null,(select membership_revision from public.staff_accounts where user_id='44556600-0000-4000-8000-000000000001'),'Inviting administrator access revoked',true);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000012',true);
do $$ begin
 if (public.staff_invitation_summary((current_setting('openhouse.stale_invite')::jsonb->>'id')::uuid)->>'can_accept')::boolean then raise exception 'Stale administrator summary offered acceptance';end if;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'accept',(current_setting('openhouse.stale_invite')::jsonb->>'id')::uuid,1,null,null,'Accept stale administrator approval',true);raise exception 'Revoked inviter approval accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.staff_membership_changes where invitation_id=(current_setting('openhouse.invite')::jsonb->>'id')::uuid)<>1 then raise exception 'Acceptance membership audit missing/duplicated';end if;
 if exists(select 1 from public.staff_accounts where user_id in('44556600-0000-4000-8000-000000000005','44556600-0000-4000-8000-000000000007','44556600-0000-4000-8000-000000000009','44556600-0000-4000-8000-000000000012')) then raise exception 'Denied/declined invite granted access';end if;
 begin update public.staff_invitations set role='admin';raise exception 'Approved role mutated';exception when unique_violation then null;end;
 begin delete from public.staff_invitation_events;raise exception 'Invitation audit deleted';exception when unique_violation then null;end;
 begin delete from public.staff_membership_changes;raise exception 'Membership audit deleted';exception when unique_violation then null;end;
end $$;
rollback;
