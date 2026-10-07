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
do $$ declare lines jsonb;posted uuid;reversed uuid;request uuid:=gen_random_uuid();begin
 lines:=jsonb_build_array(jsonb_build_object('account_id',current_setting('openhouse.debit'),'debit_minor',10001,'credit_minor',0),jsonb_build_object('account_id',current_setting('openhouse.credit'),'debit_minor',0,'credit_minor',10001));
 posted:=public.post_finance_journal(gen_random_uuid(),'JMD','Fixture original posting','Approved fixture posting',true,lines);
 reversed:=public.reverse_finance_journal(request,posted,'Approved fixture reversal',true);
 if reversed<>public.reverse_finance_journal(request,posted,' Approved fixture reversal ',true) or (select count(*) from public.finance_journals)<>2 or (select count(*) from public.finance_journal_reversals)<>1 then raise exception 'Reversal retry duplicated';end if;
 if exists(select 1 from public.finance_journal_lines a join public.finance_journal_lines b on b.line_number=a.line_number and b.journal_id=reversed where a.journal_id=posted and (a.account_id<>b.account_id or a.debit_minor<>b.credit_minor or a.credit_minor<>b.debit_minor)) then raise exception 'Reversal lines incorrect';end if;
 begin perform public.reverse_finance_journal(request,posted,'Changed fixture reversal',true);raise exception 'Changed reversal nonce accepted';exception when invalid_parameter_value then null;end;
 begin perform public.reverse_finance_journal(gen_random_uuid(),posted,'Approved duplicate reversal',true);raise exception 'Duplicate reversal accepted';exception when unique_violation then null;end;
 begin perform public.reverse_finance_journal(gen_random_uuid(),reversed,'Approved reversal of reversal',true);raise exception 'Reversal chain accepted';exception when unique_violation then null;end;
 begin perform public.reverse_finance_journal(gen_random_uuid(),posted,'Unapproved fixture reversal',false);raise exception 'Missing approval accepted';exception when invalid_parameter_value then null;end;
 perform set_config('openhouse.original',posted::text,true);
end $$;
set constraints all immediate;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.finance_journal_reversals) then raise exception 'Foreign reversal exposed';end if;
 begin perform public.reverse_finance_journal(gen_random_uuid(),current_setting('openhouse.original')::uuid,'Foreign reversal attempt',true);raise exception 'Foreign reversal accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin begin update public.finance_journal_reversals set reason='Changed';raise exception 'Reversal audit edited';exception when unique_violation then null;end;end $$;
rollback;
