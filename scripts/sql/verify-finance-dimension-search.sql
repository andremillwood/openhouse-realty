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
insert into public.properties(id,organization_id,name) values
('33445500-0000-4000-8000-000000000060','33445500-0000-4000-8000-000000000010','Journal fixture property'),
('33445500-0000-4000-8000-000000000061','33445500-0000-4000-8000-000000000010','Other fixture property');
insert into public.units(id,property_id,unit_label) values('33445500-0000-4000-8000-000000000062','33445500-0000-4000-8000-000000000060','A');
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ declare result jsonb;begin
 result:=public.search_finance_dimensions('property','Journal');
 if jsonb_array_length(result->'items')<>1 or result#>>'{items,0,label}'<>'Journal fixture property' or result#>'{items,0}' ? 'address_text' then raise exception 'Property search wrong/excess fields';end if;
 result:=public.search_finance_dimensions('unit','A','33445500-0000-4000-8000-000000000060');
 if jsonb_array_length(result->'items')<>1 or result#>>'{items,0,label}'<>'A' then raise exception 'Unit search missing';end if;
 if jsonb_array_length(public.search_finance_dimensions('property','%')->'items')<>0 then raise exception 'Wildcard search not literal';end if;
 begin perform public.search_finance_dimensions('unit','',gen_random_uuid());raise exception 'Unknown parent accepted';exception when insufficient_privilege then null;end;
 begin perform public.search_finance_dimensions('unit','');raise exception 'Missing parent accepted';exception when invalid_parameter_value then null;end;
 if exists(select 1 from public.properties) then raise exception 'Finance broad inventory read exposed';end if;
end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000004',true);
do $$ begin
 if jsonb_array_length(public.search_finance_dimensions('property','')->'items')<>0 then raise exception 'Foreign search exposed inventory';end if;
 begin perform public.search_finance_dimensions('unit','','33445500-0000-4000-8000-000000000060');raise exception 'Foreign parent accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000003',true);
do $$ begin begin perform public.search_finance_dimensions('property','');raise exception 'Manager finance search accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
