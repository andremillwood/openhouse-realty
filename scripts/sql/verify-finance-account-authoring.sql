begin;
insert into auth.users(id,email,email_confirmed_at) values
('33445500-0000-4000-8000-000000000001','finance-admin@example.invalid',now()),
('33445500-0000-4000-8000-000000000002','finance-staff@example.invalid',now()),
('33445500-0000-4000-8000-000000000003','finance-manager@example.invalid',now()),
('33445500-0000-4000-8000-000000000004','finance-foreign@example.invalid',now());
insert into public.organizations(id,name) values('33445500-0000-4000-8000-000000000010','Finance fixture'),('33445500-0000-4000-8000-000000000011','Foreign finance fixture');
insert into public.staff_accounts(user_id,organization_id,role) values
('33445500-0000-4000-8000-000000000001','33445500-0000-4000-8000-000000000010','admin'),
('33445500-0000-4000-8000-000000000002','33445500-0000-4000-8000-000000000010','finance'),
('33445500-0000-4000-8000-000000000003','33445500-0000-4000-8000-000000000010','manager'),
('33445500-0000-4000-8000-000000000004','33445500-0000-4000-8000-000000000011','admin');
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.finance_account',public.author_finance_account('33445500-0000-4000-8000-000000000040','test-a','Fixture asset','asset','Approved business chart reference',true)::text,true);
do $$ begin
 if public.author_finance_account('33445500-0000-4000-8000-000000000040',' TEST-A ','Fixture asset','asset','Approved business chart reference',true)::text<>current_setting('openhouse.finance_account') or (select count(*) from public.finance_account_approvals)<>1 then raise exception 'Account retry duplicated';end if;
 if not exists(select 1 from public.finance_accounts where id=current_setting('openhouse.finance_account')::uuid and code='TEST-A' and approved_by=auth.uid()) then raise exception 'Account identity/normalization failed';end if;
 begin perform public.author_finance_account('33445500-0000-4000-8000-000000000040','TEST-A','Changed account','asset','Approved business chart reference',true);raise exception 'Changed nonce accepted';exception when invalid_parameter_value then null;end;
 begin perform public.author_finance_account(gen_random_uuid(),'test-a','Duplicate code','asset','Approved business chart reference',true);raise exception 'Case duplicate code accepted';exception when unique_violation then null;end;
 begin perform public.author_finance_account(gen_random_uuid(),'TEST-B','Unapproved account','asset','Approved business chart reference',false);raise exception 'Missing approval accepted';exception when invalid_parameter_value then null;end;
 begin perform public.author_finance_account(gen_random_uuid(),'TEST B','Invalid code','asset','Approved business chart reference',true);raise exception 'Invalid code accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000002',true);
do $$ begin
 if (select count(*) from public.finance_accounts)<>1 or (select count(*) from public.finance_account_approvals)<>1 then raise exception 'Finance approval read missing';end if;
 begin perform public.author_finance_account(gen_random_uuid(),'TEST-F','Finance self approval','asset','Approved business chart reference',true);raise exception 'Finance created chart account';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000003',true);
do $$ begin if exists(select 1 from public.finance_accounts) or exists(select 1 from public.finance_account_approvals) then raise exception 'Manager chart exposed';end if;end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000004',true);
do $$ begin if exists(select 1 from public.finance_accounts) or exists(select 1 from public.finance_account_approvals) then raise exception 'Foreign chart exposed';end if;end $$;
select public.author_finance_account(gen_random_uuid(),'TEST-A','Foreign chart asset','asset','Approved foreign chart reference',true);
do $$ begin if (select count(*) from public.finance_accounts)<>1 or (select count(*) from public.finance_account_approvals)<>1 then raise exception 'Foreign account organization derived incorrectly';end if;end $$;
reset role;
do $$ begin begin update public.finance_account_approvals set payload='{}';raise exception 'Approval audit rewritten';exception when unique_violation then null;end;end $$;
update auth.users set email_confirmed_at=null where id='33445500-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin begin perform public.author_finance_account(gen_random_uuid(),'TEST-U','Unverified approval','asset','Approved business chart reference',true);raise exception 'Unverified admin approved';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
