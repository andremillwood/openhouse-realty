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
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.debit',public.author_finance_account(gen_random_uuid(),'TEST-A','Fixture asset','asset','Approved fixture chart',true)::text,true);
select set_config('openhouse.credit',public.author_finance_account(gen_random_uuid(),'TEST-L','Fixture liability','liability','Approved fixture chart',true)::text,true);
select public.post_finance_journal(gen_random_uuid(),'JMD','Fixture dimension posting','Approved fixture posting',true,jsonb_build_array(
jsonb_build_object('account_id',current_setting('openhouse.debit'),'property_id','33445500-0000-4000-8000-000000000060','unit_id','33445500-0000-4000-8000-000000000062','debit_minor',10001,'credit_minor',0),
jsonb_build_object('account_id',current_setting('openhouse.credit'),'debit_minor',0,'credit_minor',10001)));
set constraints all immediate;
reset role;
do $$ begin
 begin update public.properties set organization_id='33445500-0000-4000-8000-000000000011' where id='33445500-0000-4000-8000-000000000060';raise exception 'Journal property moved';exception when unique_violation then null;end;
 begin update public.units set property_id='33445500-0000-4000-8000-000000000061' where id='33445500-0000-4000-8000-000000000062';raise exception 'Journal unit moved';exception when unique_violation then null;end;
end $$;
update public.properties set name='Corrected descriptive name' where id='33445500-0000-4000-8000-000000000060';
update public.units set unit_label='Corrected label' where id='33445500-0000-4000-8000-000000000062';
update public.properties set organization_id='33445500-0000-4000-8000-000000000011' where id='33445500-0000-4000-8000-000000000061';
do $$ begin
 if not exists(select 1 from public.properties where id='33445500-0000-4000-8000-000000000060' and organization_id='33445500-0000-4000-8000-000000000010' and name='Corrected descriptive name') then raise exception 'Property history/descriptive edit failed';end if;
 if not exists(select 1 from public.units where id='33445500-0000-4000-8000-000000000062' and property_id='33445500-0000-4000-8000-000000000060' and unit_label='Corrected label') then raise exception 'Unit history/descriptive edit failed';end if;
end $$;
rollback;
