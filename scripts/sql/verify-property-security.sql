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

insert into public.properties(id,organization_id,name) values('22334400-0000-4000-8000-000000000010','22334400-0000-4000-8000-000000000007','Security property'),('22334400-0000-4000-8000-000000000011','22334400-0000-4000-8000-000000000008','Foreign property');
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 begin perform public.author_property_security_assignment(gen_random_uuid(),null,0,'22334400-0000-4000-8000-000000000010','contractor-target@example.invalid',true,'Approved security coverage',false);raise exception 'Approval not required';exception when invalid_parameter_value then null;end;
 begin perform public.author_property_security_assignment(gen_random_uuid(),null,0,'22334400-0000-4000-8000-000000000011','contractor-target@example.invalid',true,'Approved security coverage',true);raise exception 'Foreign property approved';exception when insufficient_privilege then null;end;
 begin perform public.author_property_security_assignment(gen_random_uuid(),null,0,'22334400-0000-4000-8000-000000000010','contractor-unverified@example.invalid',true,'Approved security coverage',true);raise exception 'Unverified security approved';exception when insufficient_privilege then null;end;
end $$;
select set_config('openhouse.security',public.author_property_security_assignment('22334400-0000-4000-8000-000000000012',null,0,'22334400-0000-4000-8000-000000000010','contractor-target@example.invalid',true,'Approved security coverage',true)->>'id',true);
select public.author_property_security_assignment('22334400-0000-4000-8000-000000000012',null,0,'22334400-0000-4000-8000-000000000010','contractor-target@example.invalid',true,'Approved security coverage',true);
do $$ begin
 if(select count(*) from public.property_security_assignments)<>1 or(select count(*) from public.property_security_assignment_changes)<>1 then raise exception 'Retry duplicate';end if;
 begin perform public.author_property_security_assignment(gen_random_uuid(),null,0,'22334400-0000-4000-8000-000000000010','contractor-target@example.invalid',true,'Duplicate coverage approval',true);raise exception 'Duplicate property assignment';exception when unique_violation then null;end;
 begin perform public.author_property_security_assignment(gen_random_uuid(),current_setting('openhouse.security')::uuid,0,null,null,false,'Stale security revocation',true);raise exception 'Stale edit allowed';exception when serialization_failure then null;end;
 begin update public.property_security_assignments set is_active=false;raise exception 'Direct security edits';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
do $$ begin
 if(select count(*) from public.property_security_assignments)<>1 or exists(select 1 from public.property_security_assignment_changes) then raise exception 'Own security privacy failed';end if;
 if exists(select 1 from public.work_orders) then raise exception 'Security read internal work';end if;
 begin perform public.author_property_security_assignment(gen_random_uuid(),current_setting('openhouse.security')::uuid,1,null,null,false,'Self security revocation',true);raise exception 'Security self approved';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000004',true);
do $$ begin if exists(select 1 from public.property_security_assignments) or exists(select 1 from public.property_security_assignment_changes) then raise exception 'Foreign security data visible';end if;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
select public.author_property_security_assignment(gen_random_uuid(),current_setting('openhouse.security')::uuid,1,null,null,false,'Security coverage withdrawn',true);
reset role;
do $$ begin
 begin update public.property_security_assignments set property_id='22334400-0000-4000-8000-000000000011' where id=current_setting('openhouse.security')::uuid;raise exception 'Trusted property reassignment';exception when unique_violation then null;end;
 begin update public.properties set organization_id='22334400-0000-4000-8000-000000000008' where id='22334400-0000-4000-8000-000000000010';raise exception 'Security property organization changed';exception when unique_violation then null;end;
 update auth.users set email_confirmed_at=null where id='22334400-0000-4000-8000-000000000002';
end $$;
set local role authenticated;
do $$ begin begin perform public.author_property_security_assignment(gen_random_uuid(),current_setting('openhouse.security')::uuid,2,null,null,true,'Unverified security activation',true);raise exception 'Unverified reactivated';exception when insufficient_privilege then null;end;end $$;
select public.author_property_security_assignment(gen_random_uuid(),current_setting('openhouse.security')::uuid,2,null,null,false,'Unverified security remains inactive',true);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.property_security_assignments) then raise exception 'Unverified security reads';end if;end $$;
reset role;
rollback;
