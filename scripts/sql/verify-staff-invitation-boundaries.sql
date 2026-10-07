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
insert into public.staff_invitations(id,organization_id,created_by,invite_email,role,expires_at) values('44556600-0000-4000-8000-000000000080','44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000001','staff-expired@example.invalid','manager',now()-interval '1 hour');
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000008',true);
set local role authenticated;
do $$ begin
 if (public.staff_invitation_summary('44556600-0000-4000-8000-000000000080')->>'can_accept')::boolean or (public.staff_invitation_summary('44556600-0000-4000-8000-000000000080')->>'can_decline')::boolean then raise exception 'Expired invitation offered decision';end if;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'accept','44556600-0000-4000-8000-000000000080',1,null,null,'Accept expired invitation',true);raise exception 'Expired acceptance succeeded';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
select set_config('openhouse.replacement',public.manage_staff_invitation('44556600-0000-4000-8000-000000000081','create',null,0,'staff-expired@example.invalid','finance','New approval after expiry',true)::text,true);
do $$ begin
 if not exists(select id from public.staff_invitations where id='44556600-0000-4000-8000-000000000080' and state='expired' and version=2) then raise exception 'Old invitation not expired';end if;
 if (select count(*) from public.staff_invitation_events where invitation_id='44556600-0000-4000-8000-000000000080' and action='expire')<>1 then raise exception 'Expiry audit missing';end if;
 if public.manage_staff_invitation('44556600-0000-4000-8000-000000000081','create',null,0,'staff-expired@example.invalid','finance','New approval after expiry',true)<>current_setting('openhouse.replacement')::jsonb then raise exception 'Replacement retry changed';end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000014',true);
do $$ begin
 for n in 1..10 loop perform public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'daily-'||n||'@example.invalid','realtor','Approved daily quota fixture',true);end loop;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'daily-eleventh@example.invalid','realtor','Over daily quota fixture',true);raise exception 'Eleventh daily invitation allowed';exception when unique_violation then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
insert into public.staff_invitations(organization_id,created_by,invite_email,role) select '44556600-0000-4000-8000-000000000010'::uuid,'44556600-0000-4000-8000-000000000001'::uuid,'active-'||n||'@example.invalid','realtor' from generate_series(1,89) n;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 if (select count(id) from public.staff_invitations where state='pending' and expires_at>now())<>100 then raise exception 'Active quota setup wrong';end if;
 begin perform public.manage_staff_invitation(gen_random_uuid(),'create',null,0,'active-overflow@example.invalid','finance','Over organization quota fixture',true);raise exception '101st active invitation allowed';exception when unique_violation then null;end;
end $$;
reset role;
rollback;
