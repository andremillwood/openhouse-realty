begin;
insert into auth.users(id,email,email_confirmed_at) values
('22334400-0000-4000-8000-000000000001','contractor-manager@example.invalid',now()),
('22334400-0000-4000-8000-000000000002','contractor-target@example.invalid',now()),
('22334400-0000-4000-8000-000000000003','contractor-unverified@example.invalid',null),
('22334400-0000-4000-8000-000000000004','contractor-foreign@example.invalid',now()),
('22334400-0000-4000-8000-000000000005','contractor-realtor@example.invalid',now()),
('22334400-0000-4000-8000-000000000006','contractor-prospect@example.invalid',now());
insert into public.organizations(id,name) values('22334400-0000-4000-8000-000000000007','Contractor fixtures'),('22334400-0000-4000-8000-000000000008','Foreign contractor fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
('22334400-0000-4000-8000-000000000001','22334400-0000-4000-8000-000000000007','manager'),
('22334400-0000-4000-8000-000000000003','22334400-0000-4000-8000-000000000007','manager'),
('22334400-0000-4000-8000-000000000004','22334400-0000-4000-8000-000000000008','manager'),
('22334400-0000-4000-8000-000000000005','22334400-0000-4000-8000-000000000007','realtor');
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 begin perform public.author_contractor_account(gen_random_uuid(),null,0,'contractor-target@example.invalid','Approved Contractor',array['Plumbing'],true,'Approved registration',false);raise exception 'Missing approval accepted';exception when invalid_parameter_value then null;end;
 begin perform public.author_contractor_account(gen_random_uuid(),null,0,'contractor-unverified@example.invalid','Approved Contractor',array['Plumbing'],true,'Approved registration',true);raise exception 'Unverified contractor accepted';exception when insufficient_privilege then null;end;
 begin perform public.author_contractor_account(gen_random_uuid(),null,0,'contractor-target@example.invalid','Approved Contractor',array[null::text],true,'Approved registration',true);raise exception 'Invalid trade accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('openhouse.contractor_account',public.author_contractor_account('22334400-0000-4000-8000-000000000009',null,0,' Contractor-Target@example.invalid ',' Approved Contractor ',array['Plumbing',' Electrical ','Plumbing'],true,'Approved registration',true)->>'id',true);
do $$ begin
 if not exists(select 1 from public.contractor_accounts where id=current_setting('openhouse.contractor_account')::uuid and organization_id='22334400-0000-4000-8000-000000000007' and user_id='22334400-0000-4000-8000-000000000002' and company_name='Approved Contractor' and trade_coverage=array['Electrical','Plumbing']::text[] and version=1) then raise exception 'Contractor binding/normalization failed';end if;
 if public.author_contractor_account('22334400-0000-4000-8000-000000000009',null,0,'contractor-target@example.invalid','Approved Contractor',array['Electrical','Plumbing'],true,'Approved registration',true)->>'id'<>current_setting('openhouse.contractor_account') then raise exception 'Retry duplicated registration';end if;
 if (select count(*) from public.contractor_account_changes)<>1 then raise exception 'Retry duplicated audit';end if;
 begin perform public.author_contractor_account('22334400-0000-4000-8000-000000000009',null,0,'contractor-target@example.invalid','Changed Contractor',array['Electrical','Plumbing'],true,'Approved registration',true);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.author_contractor_account(gen_random_uuid(),null,0,'contractor-target@example.invalid','Approved Contractor',array['Plumbing'],true,'Duplicate registration',true);raise exception 'Duplicate organization registration accepted';exception when unique_violation then null;end;
 begin perform public.author_contractor_account(gen_random_uuid(),current_setting('openhouse.contractor_account')::uuid,0,null,'Approved Contractor',array['Plumbing'],false,'Stale deactivation',true);raise exception 'Stale edit accepted';exception when serialization_failure then null;end;
 begin update public.contractor_accounts set is_active=false where id=current_setting('openhouse.contractor_account')::uuid;raise exception 'Direct registry write allowed';exception when insufficient_privilege then null;end;
 begin delete from public.contractor_account_changes;raise exception 'Audit deletion allowed';exception when insufficient_privilege then null;end;
end $$;
select public.author_contractor_account(gen_random_uuid(),current_setting('openhouse.contractor_account')::uuid,1,null,'Approved Contractor',array['Plumbing'],false,'Registration temporarily withdrawn',true);
do $$ begin if not exists(select 1 from public.contractor_account_changes where account_id=current_setting('openhouse.contractor_account')::uuid and version=2 and actor_user_id=auth.uid() and before_record->>'is_active'='true' and after_record->>'is_active'='false') then raise exception 'Deactivation audit missing';end if;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
do $$ begin
 if (select count(*) from public.contractor_accounts)<>1 then raise exception 'Own registration unavailable';end if;
 if exists(select 1 from public.contractor_account_changes) then raise exception 'Contractor saw management reasons';end if;
 begin perform public.author_contractor_account(gen_random_uuid(),current_setting('openhouse.contractor_account')::uuid,2,null,'Approved Contractor',array['Plumbing'],true,'Contractor self activation',true);raise exception 'Contractor self activated';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.contractor_accounts where id=current_setting('openhouse.contractor_account')::uuid) or exists(select 1 from public.contractor_account_changes) then raise exception 'Foreign private registry visible';end if;
 begin perform public.author_contractor_account(gen_random_uuid(),current_setting('openhouse.contractor_account')::uuid,2,null,'Approved Contractor',array['Plumbing'],true,'Foreign activation',true);raise exception 'Foreign manager edited registry';exception when insufficient_privilege then null;end;
end $$;
select public.author_contractor_account(gen_random_uuid(),null,0,'contractor-target@example.invalid','Other Approved Contractor',array['Plumbing'],true,'Separate approved organization',true);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
do $$ begin if (select count(*) from public.contractor_accounts)<>2 then raise exception 'Separate own registrations not available';end if;end $$;
reset role;
do $$ begin
 begin update public.contractor_accounts set user_id='22334400-0000-4000-8000-000000000006' where id=current_setting('openhouse.contractor_account')::uuid;raise exception 'Trusted identity reassigned';exception when unique_violation then null;end;
 update auth.users set email_confirmed_at=null where id='22334400-0000-4000-8000-000000000002';
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin begin perform public.author_contractor_account(gen_random_uuid(),current_setting('openhouse.contractor_account')::uuid,2,null,'Approved Contractor',array['Plumbing'],true,'Unverified reactivation',true);raise exception 'Unverified reactivation allowed';exception when insufficient_privilege then null;end;end $$;
select public.author_contractor_account(gen_random_uuid(),current_setting('openhouse.contractor_account')::uuid,2,null,'Approved Contractor',array['Plumbing'],false,'Unverified registration stays inactive',true);
do $$ declare caller uuid;begin
 foreach caller in array array['22334400-0000-4000-8000-000000000002'::uuid,'22334400-0000-4000-8000-000000000003'::uuid,'22334400-0000-4000-8000-000000000005'::uuid,'22334400-0000-4000-8000-000000000006'::uuid] loop
 perform set_config('request.jwt.claim.sub',caller::text,true);
 if exists(select 1 from public.contractor_accounts) or exists(select 1 from public.contractor_account_changes) then raise exception 'Unauthorized registry read';end if;
 begin perform public.author_contractor_account(gen_random_uuid(),null,0,'contractor-target@example.invalid','Approved Contractor',array['Plumbing'],true,'Unauthorized approval',true);raise exception 'Unauthorized approver accepted';exception when insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
set local role anon;
do $$ begin begin perform 1 from public.contractor_accounts;raise exception 'Anonymous registry read';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
