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
select set_config('openhouse.debit',public.author_finance_account(gen_random_uuid(),'TEST-A','Fixture asset','asset','Approved fixture chart',true)::text,true);
select set_config('openhouse.credit',public.author_finance_account(gen_random_uuid(),'TEST-L','Fixture liability','liability','Approved fixture chart',true)::text,true);
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000002',true);
do $$ declare lines jsonb;posted uuid;request uuid:=gen_random_uuid();bad jsonb;begin
 lines:=jsonb_build_array(jsonb_build_object('account_id',current_setting('openhouse.debit'),'debit_minor',10001,'credit_minor',0),jsonb_build_object('account_id',current_setting('openhouse.credit'),'debit_minor',0,'credit_minor',10001));
 posted:=public.post_finance_journal(request,'JMD','Fixture balanced posting','Approved fixture posting',true,lines);
 if posted<>public.post_finance_journal(request,'JMD',' Fixture balanced posting ','Approved fixture posting',true,lines) or (select count(*) from public.finance_journals)<>1 or (select count(*) from public.finance_journal_lines)<>2 then raise exception 'Posting retry duplicated';end if;
 if not exists(select 1 from public.finance_journals where id=posted and posted_by=auth.uid() and organization_id='33445500-0000-4000-8000-000000000010') then raise exception 'Posting authority incorrect';end if;
 begin perform public.post_finance_journal(request,'JMD','Changed fixture posting','Approved fixture posting',true,lines);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.post_finance_journal(gen_random_uuid(),'JMD','Fixture posting','Approved fixture posting',false,lines);raise exception 'Unapproved posting accepted';exception when invalid_parameter_value then null;end;
 bad:=jsonb_set(lines,'{1,credit_minor}','10000');
 begin perform public.post_finance_journal(gen_random_uuid(),'JMD','Fixture posting','Approved fixture posting',true,bad);raise exception 'Imbalance accepted';exception when invalid_parameter_value then null;end;
 bad:=jsonb_set(lines,'{0,debit_minor}','10001.5');
 begin perform public.post_finance_journal(gen_random_uuid(),'JMD','Fixture posting','Approved fixture posting',true,bad);raise exception 'Fraction accepted';exception when invalid_parameter_value then null;end;
 bad:=jsonb_set(lines,'{0,debit_minor}','"10001"');
 begin perform public.post_finance_journal(gen_random_uuid(),'JMD','Fixture posting','Approved fixture posting',true,bad);raise exception 'String amount accepted';exception when invalid_parameter_value then null;end;
 bad:=jsonb_set(lines,'{0,account_id}',to_jsonb(gen_random_uuid()::text));
 begin perform public.post_finance_journal(gen_random_uuid(),'JMD','Fixture posting','Approved fixture posting',true,bad);raise exception 'Unknown account accepted';exception when insufficient_privilege then null;end;
 if (select count(*) from public.finance_journals)<>1 or (select count(*) from public.finance_journal_lines)<>2 then raise exception 'Failed posting leaked records';end if;
end $$;
set constraints all immediate;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000003',true);
do $$ begin begin perform public.post_finance_journal(gen_random_uuid(),'JMD','Fixture posting','Approved fixture posting',true,'[]');raise exception 'Manager posting accepted';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000004',true);
do $$ declare lines jsonb;begin
 lines:=jsonb_build_array(jsonb_build_object('account_id',current_setting('openhouse.debit'),'debit_minor',10001,'credit_minor',0),jsonb_build_object('account_id',current_setting('openhouse.credit'),'debit_minor',0,'credit_minor',10001));
 begin perform public.post_finance_journal(gen_random_uuid(),'JMD','Foreign fixture posting','Approved fixture posting',true,lines);raise exception 'Foreign account posting accepted';exception when insufficient_privilege then null;end;
 if exists(select 1 from public.finance_journals) then raise exception 'Foreign journal exposed';end if;
end $$;
reset role;
update auth.users set email_confirmed_at=null where id='33445500-0000-4000-8000-000000000002';
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin begin perform public.post_finance_journal(gen_random_uuid(),'JMD','Fixture posting','Approved fixture posting',true,'[]');raise exception 'Unverified posting accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
