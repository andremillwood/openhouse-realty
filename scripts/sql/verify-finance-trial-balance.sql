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
do $$ declare lines jsonb;result jsonb;today date:=(now() at time zone 'America/Jamaica')::date;begin
 lines:=jsonb_build_array(jsonb_build_object('account_id',current_setting('openhouse.debit'),'debit_minor',10001,'credit_minor',0),jsonb_build_object('account_id',current_setting('openhouse.credit'),'debit_minor',0,'credit_minor',10001));
 for i in 1..30 loop perform public.post_finance_journal(gen_random_uuid(),'JMD','Fixture statement posting','Approved fixture posting',true,lines);end loop;
 result:=public.finance_account_statement(current_setting('openhouse.debit')::uuid,today,today,2);
 if result->>'opening_minor'<>'0' or result->>'closing_minor'<>'300030' or result->>'debit_minor'<>'300030' or result->>'total'<>'30' or result->>'pages'<>'2' or jsonb_array_length(result->'entries')<>5 or result#>>'{entries,4,balance_minor}'<>'300030' then raise exception 'Statement totals/pagination/running balance failed: %',result;end if;
 result:=public.finance_account_statement(current_setting('openhouse.debit')::uuid,today+1,today+1,999);
 if result->>'opening_minor'<>'300030' or result->>'closing_minor'<>'300030' or result->>'page'<>'1' or jsonb_array_length(result->'entries')<>0 then raise exception 'Opening balance/empty page failed';end if;
 result:=public.finance_account_statement(current_setting('openhouse.credit')::uuid,today,today);
 if result->>'closing_minor'<>'-300030' then raise exception 'Credit balance sign failed';end if;
 result:=public.finance_trial_balance(today);
 if result->>'balanced'<>'true' or result->>'debit_minor'<>'300030' or result->>'credit_minor'<>'300030' or jsonb_array_length(result->'accounts')<>2 then raise exception 'Trial balance totals failed';end if;
 result:=public.finance_trial_balance(today-1,999);
 if result->>'debit_minor'<>'0' or result->>'credit_minor'<>'0' or result->>'page'<>'1' then raise exception 'Trial cutoff/empty totals failed';end if;
 begin perform public.finance_account_statement(current_setting('openhouse.debit')::uuid,today,today+367);raise exception 'Excess date range accepted';exception when invalid_parameter_value then null;end;
 begin perform public.finance_account_statement(current_setting('openhouse.debit')::uuid,today,today-1);raise exception 'Reversed date range accepted';exception when invalid_parameter_value then null;end;
end $$;
do $$ declare lines jsonb;posted uuid;result jsonb;today date:=(now() at time zone 'America/Jamaica')::date;begin
 select jsonb_agg(jsonb_build_object('account_id',case when i<=100 then current_setting('openhouse.debit') else current_setting('openhouse.credit') end,'debit_minor',case when i<=100 then 99999999999999::bigint else 0 end,'credit_minor',case when i>100 then 99999999999999::bigint else 0 end) order by i) into lines from generate_series(1,200) i;
 posted:=public.post_finance_journal(gen_random_uuid(),'JMD','Fixture large statement posting','Approved fixture posting',true,lines);
 result:=public.finance_account_statement(current_setting('openhouse.debit')::uuid,today,today,999);
 if result->>'closing_minor'<>'10000000000299930' or result->>'debit_minor'<>'10000000000299930' or result->>'total'<>'130' or result#>>'{entries,4,balance_minor}'<>'10000000000299930' or jsonb_typeof(result->'closing_minor')<>'string' then raise exception 'Large statement precision failed: %',result;end if;
 result:=public.finance_trial_balance(today);
 if result->>'debit_minor'<>'10000000000299930' or result->>'credit_minor'<>'10000000000299930' or jsonb_typeof(result->'debit_minor')<>'string' or result->>'balanced'<>'true' then raise exception 'Trial large precision failed';end if;
 perform public.reverse_finance_journal(gen_random_uuid(),posted,'Approved large fixture reversal',true);
 result:=public.finance_account_statement(current_setting('openhouse.debit')::uuid,today,today,999);
 if result->>'closing_minor'<>'300030' or result->>'credit_minor'<>'9999999999999900' or result->>'total'<>'230' or result#>>'{entries,4,balance_minor}'<>'300030' then raise exception 'Reversal statement failed: %',result;end if;
 result:=public.finance_trial_balance(today);
 if result->>'debit_minor'<>'300030' or result->>'credit_minor'<>'300030' or result->>'balanced'<>'true' then raise exception 'Trial reversal netting failed';end if;
end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000001',true);
do $$ begin for i in 1..27 loop perform public.author_finance_account(gen_random_uuid(),'ZERO-'||lpad(i::text,2,'0'),'Approved zero account '||i,'asset','Approved fixture chart',true);end loop;end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000002',true);
do $$ declare result jsonb;begin
 result:=public.finance_trial_balance((now() at time zone 'America/Jamaica')::date,999);
 if result->>'page'<>'2' or result->>'pages'<>'2' or result->>'total'<>'29' or jsonb_array_length(result->'accounts')<>4 or result->>'debit_minor'<>'300030' or result->>'credit_minor'<>'300030' then raise exception 'Trial pagination/full totals failed';end if;
end $$;
set constraints all immediate;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000004',true);
do $$ begin if jsonb_array_length(public.finance_trial_balance(current_date)->'accounts')<>0 then raise exception 'Foreign trial balance exposed';end if;end $$;
do $$ begin begin perform public.finance_account_statement(current_setting('openhouse.debit')::uuid,current_date,current_date);raise exception 'Foreign statement exposed';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000003',true);
do $$ begin begin perform public.finance_account_statement(current_setting('openhouse.debit')::uuid,current_date,current_date);raise exception 'Manager statement exposed';exception when insufficient_privilege then null;end;end $$;
do $$ begin begin perform public.finance_trial_balance(current_date);raise exception 'Manager trial balance exposed';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
