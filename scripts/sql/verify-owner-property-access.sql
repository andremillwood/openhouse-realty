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
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.owner_access',public.author_owner_property_access('44556600-0000-4000-8000-000000000030',null,0,'44556600-0000-4000-8000-000000000020',' Approved-Owner@example.invalid ',true,'Approved portfolio access',true)::text,true);
do $$ declare first jsonb:=current_setting('openhouse.owner_access')::jsonb;again jsonb;begin
 again:=public.author_owner_property_access('44556600-0000-4000-8000-000000000030',null,0,'44556600-0000-4000-8000-000000000020','approved-owner@example.invalid',true,'Approved portfolio access',true);
 if first<>again or (select count(*) from public.owner_property_access_changes)<>1 then raise exception 'Exact retry failed';end if;
 begin perform public.author_owner_property_access('44556600-0000-4000-8000-000000000030',null,0,'44556600-0000-4000-8000-000000000020','approved-owner@example.invalid',true,'Different approval reason',true);raise exception 'Changed retry allowed';exception when invalid_parameter_value then null;end;
 begin perform public.author_owner_property_access(gen_random_uuid(),null,0,'44556600-0000-4000-8000-000000000021','approved-owner@example.invalid',true,'Approved foreign property',true);raise exception 'Foreign property allowed';exception when insufficient_privilege then null;end;
 begin perform public.author_owner_property_access(gen_random_uuid(),null,0,'44556600-0000-4000-8000-000000000020','unverified-owner@example.invalid',true,'Approved unverified owner',true);raise exception 'Unverified recipient allowed';exception when insufficient_privilege then null;end;
 begin perform public.author_owner_property_access(gen_random_uuid(),null,0,'44556600-0000-4000-8000-000000000020','other-owner@example.invalid',true,'Approval not attested',false);raise exception 'Approval absent allowed';exception when invalid_parameter_value then null;end;
 begin update public.owner_property_access set is_active=false;raise exception 'Direct write allowed';exception when insufficient_privilege then null;end;
 begin perform public.author_owner_property_access(gen_random_uuid(),(first->>'id')::uuid,0,null,null,false,'Approved access withdrawal',true);raise exception 'Stale version allowed';exception when serialization_failure then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ begin
 if (select count(*) from public.owner_property_access)<>1 or (select count(*) from public.owner_property_access_changes)<>0 then raise exception 'Owner register/audit isolation failed';end if;
 begin perform public.author_owner_property_access(gen_random_uuid(),null,0,'44556600-0000-4000-8000-000000000020','other-owner@example.invalid',true,'Owner self grant attempt',true);raise exception 'Owner self grant allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
do $$ begin
 if (select count(*) from public.owner_property_access)<>0 or (select count(*) from public.owner_property_access_changes)<>0 then raise exception 'Manager read allowed';end if;
 begin perform public.author_owner_property_access(gen_random_uuid(),null,0,'44556600-0000-4000-8000-000000000020','other-owner@example.invalid',true,'Manager grant attempt',true);raise exception 'Manager grant allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin
 if (select count(*) from public.owner_property_access)<>0 or (select count(*) from public.owner_property_access_changes)<>0 then raise exception 'Foreign administrator read allowed';end if;
 begin perform public.author_owner_property_access(gen_random_uuid(),(current_setting('openhouse.owner_access')::jsonb->>'id')::uuid,1,null,null,false,'Foreign withdrawal attempt',true);raise exception 'Foreign withdrawal allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
select public.author_owner_property_access('44556600-0000-4000-8000-000000000031',(current_setting('openhouse.owner_access')::jsonb->>'id')::uuid,1,null,null,false,'Approved access withdrawal',true);
-- Replaying an old grant is harmless: it returns its historic result without reactivating.
select public.author_owner_property_access('44556600-0000-4000-8000-000000000030',null,0,'44556600-0000-4000-8000-000000000020','approved-owner@example.invalid',true,'Approved portfolio access',true);
do $$ begin
 if exists(select 1 from public.owner_property_access where is_active) or (select count(*) from public.owner_property_access_changes)<>2 then raise exception 'Withdrawal/replay failure';end if;
end $$;
reset role;
do $$ begin
 begin update public.properties set organization_id='44556600-0000-4000-8000-000000000011' where id='44556600-0000-4000-8000-000000000020';raise exception 'Property history moved';exception when unique_violation then null;end;
 begin update public.owner_property_access set user_id='44556600-0000-4000-8000-000000000004';raise exception 'Owner identity moved';exception when unique_violation then null;end;
 begin delete from public.owner_property_access_changes;raise exception 'Audit deleted';exception when unique_violation then null;end;
 update auth.users set email_confirmed_at=null where id='44556600-0000-4000-8000-000000000002';
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin if (select count(*) from public.owner_property_access)<>0 then raise exception 'Unverified owner read allowed';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
do $$ begin
 begin perform public.author_owner_property_access(gen_random_uuid(),(current_setting('openhouse.owner_access')::jsonb->>'id')::uuid,2,null,null,true,'Approved reactivation attempt',true);raise exception 'Unverified reactivation allowed';exception when insufficient_privilege then null;end;
end $$;
rollback;
