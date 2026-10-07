begin;
insert into auth.users(id,email,email_confirmed_at) values
('00112233-0000-4000-8000-000000000001','membership-admin@example.invalid',now()),
('00112233-0000-4000-8000-000000000002','membership-target@example.invalid',now()),
('00112233-0000-4000-8000-000000000003','membership-unverified@example.invalid',null),
('00112233-0000-4000-8000-000000000004','membership-foreign@example.invalid',now()),
('00112233-0000-4000-8000-000000000005','membership-prospect@example.invalid',now());
insert into public.organizations(id,name) values('00112233-0000-4000-8000-000000000006','Membership fixtures'),('00112233-0000-4000-8000-000000000007','Foreign membership fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
('00112233-0000-4000-8000-000000000001','00112233-0000-4000-8000-000000000006','admin'),
('00112233-0000-4000-8000-000000000003','00112233-0000-4000-8000-000000000006','admin'),
('00112233-0000-4000-8000-000000000004','00112233-0000-4000-8000-000000000007','admin');
select set_config('request.jwt.claim.sub','00112233-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.admin_revision',(select membership_revision::text from public.staff_accounts where user_id=auth.uid()),true);
select set_config('openhouse.unverified_revision',(select membership_revision::text from public.staff_accounts where user_id='00112233-0000-4000-8000-000000000003'),true);
do $$ begin
 begin perform public.manage_staff_membership(gen_random_uuid(),'membership-admin@example.invalid',null,current_setting('openhouse.admin_revision')::uuid,'Remove last administrator',true);raise exception 'Last verified administrator removed';exception when unique_violation then null;end;
 begin perform public.manage_staff_membership(gen_random_uuid(),'membership-target@example.invalid','admin',null,'Missing approval',false);raise exception 'Missing approval accepted';exception when invalid_parameter_value then null;end;
 begin perform public.manage_staff_membership(gen_random_uuid(),'membership-unverified@example.invalid','realtor',current_setting('openhouse.unverified_revision')::uuid,'Unverified account promoted',true);raise exception 'Unverified assignment accepted';exception when insufficient_privilege then null;end;
 begin update public.staff_accounts set role='realtor' where user_id=auth.uid();raise exception 'Direct membership write accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('openhouse.target_revision',public.manage_staff_membership('00112233-0000-4000-8000-000000000008',' Membership-Target@example.invalid ','realtor',null,'Approved team assignment',true)->>'revision',true);
do $$ begin
 if public.manage_staff_membership('00112233-0000-4000-8000-000000000008','membership-target@example.invalid','realtor',null,'Approved team assignment',true)->>'revision'<>current_setting('openhouse.target_revision') then raise exception 'Retry changed revision';end if;
 if (select count(*) from public.staff_membership_changes)<>1 then raise exception 'Duplicate membership audit';end if;
 if not exists(select 1 from public.staff_membership_changes where organization_id='00112233-0000-4000-8000-000000000006' and actor_user_id=auth.uid() and target_user_id='00112233-0000-4000-8000-000000000002' and new_role='realtor' and previous_role is null) then raise exception 'Derived audit incorrect';end if;
 begin perform public.manage_staff_membership('00112233-0000-4000-8000-000000000008','membership-target@example.invalid','realtor',null,'Changed request reason',true);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.manage_staff_membership(gen_random_uuid(),'membership-target@example.invalid','admin',null,'Stale role update',true);raise exception 'Stale revision accepted';exception when serialization_failure then null;end;
end $$;
select set_config('openhouse.target_revision',public.manage_staff_membership(gen_random_uuid(),'membership-target@example.invalid','admin',current_setting('openhouse.target_revision')::uuid,'Approved backup administrator',true)->>'revision',true);
select set_config('openhouse.admin_revision',public.manage_staff_membership(gen_random_uuid(),'membership-admin@example.invalid','manager',current_setting('openhouse.admin_revision')::uuid,'Approved administrator handover',true)->>'revision',true);
do $$ begin
 if private.verified_staff_admin_organization() is not null then raise exception 'Demoted caller retained admin authority';end if;
 begin perform public.manage_staff_membership(gen_random_uuid(),'membership-prospect@example.invalid','admin',null,'Demoted actor writes again',true);raise exception 'Demoted caller wrote';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00112233-0000-4000-8000-000000000002',true);
select public.manage_staff_membership(gen_random_uuid(),'membership-unverified@example.invalid',null,current_setting('openhouse.unverified_revision')::uuid,'Revoke unverified staff access',true);
select public.manage_staff_membership(gen_random_uuid(),'membership-admin@example.invalid',null,current_setting('openhouse.admin_revision')::uuid,'Revoke former administrator access',true);
do $$ declare directory jsonb;begin
 directory:=public.staff_membership_directory(999);
 if directory->>'page'<>'1' or directory->>'total'<>'1' or jsonb_array_length(directory->'rows')<>1 or directory->'rows'->0->>'email'<>'membership-target@example.invalid' then raise exception 'Directory scope or clipping failed';end if;
 begin perform public.manage_staff_membership(gen_random_uuid(),'membership-target@example.invalid','finance',current_setting('openhouse.target_revision')::uuid,'Demote last administrator',true);raise exception 'Last admin demoted';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','00112233-0000-4000-8000-000000000001',true);
do $$ begin if private.verified_enquiry_staff_organization() is not null then raise exception 'Revoked staff retained operational authority';end if;end $$;
select set_config('request.jwt.claim.sub','00112233-0000-4000-8000-000000000002',true);
select public.manage_staff_membership(gen_random_uuid(),'membership-admin@example.invalid','finance',null,'Approved finance reassignment',true);
do $$ begin
 begin perform public.manage_staff_membership(gen_random_uuid(),'membership-admin@example.invalid',null,current_setting('openhouse.admin_revision')::uuid,'Stale revoke after reassignment',true);raise exception 'Old revision revoked new membership';exception when serialization_failure then null;end;
 begin delete from public.staff_membership_changes;raise exception 'Client removed audit';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00112233-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.staff_membership_changes) then raise exception 'Foreign audit visible';end if;
 begin perform public.manage_staff_membership(gen_random_uuid(),'membership-target@example.invalid','finance',current_setting('openhouse.target_revision')::uuid,'Foreign role reassignment',true);raise exception 'Foreign role changed';exception when insufficient_privilege then null;end;
 if public.staff_membership_directory(1)->>'total'<>'1' then raise exception 'Foreign directory isolation failed';end if;
end $$;
select set_config('request.jwt.claim.sub','00112233-0000-4000-8000-000000000005',true);
do $$ begin
 if exists(select 1 from public.staff_membership_changes) then raise exception 'Prospect audit visible';end if;
 begin perform public.staff_membership_directory(1);raise exception 'Prospect directory allowed';exception when insufficient_privilege then null;end;
 begin perform public.manage_staff_membership(gen_random_uuid(),'membership-prospect@example.invalid','admin',null,'Prospect self assignment',true);raise exception 'Prospect self assigned';exception when insufficient_privilege then null;end;
end $$;
reset role;
insert into auth.users(id,email,email_confirmed_at) select ('00112233-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'bounded-member-'||i||'@example.invalid',now() from generate_series(100,129)i;
insert into public.staff_accounts(user_id,organization_id,role) select ('00112233-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'00112233-0000-4000-8000-000000000006','finance' from generate_series(100,129)i;
select set_config('request.jwt.claim.sub','00112233-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ declare directory jsonb;begin
 directory:=public.staff_membership_directory(1);if directory->>'total'<>'32' or directory->>'pages'<>'2' or jsonb_array_length(directory->'rows')<>25 then raise exception 'First directory page unbounded';end if;
 directory:=public.staff_membership_directory(999);if directory->>'page'<>'2' or jsonb_array_length(directory->'rows')<>7 then raise exception 'Final directory page incorrect';end if;
end $$;
reset role;
set local role anon;
do $$ begin begin perform public.staff_membership_directory(1);raise exception 'Anonymous directory allowed';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
