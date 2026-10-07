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
insert into public.units(property_id,unit_label) values
('44556600-0000-4000-8000-000000000020','A'),('44556600-0000-4000-8000-000000000020','B'),('44556600-0000-4000-8000-000000000021','Foreign unit');
insert into public.work_orders(property_id,organization_id,title,status) values
('44556600-0000-4000-8000-000000000020','44556600-0000-4000-8000-000000000010','Open fixture job','reported'),
('44556600-0000-4000-8000-000000000020','44556600-0000-4000-8000-000000000010','Closed fixture job','closed'),
('44556600-0000-4000-8000-000000000020','44556600-0000-4000-8000-000000000010','Cancelled fixture job','cancelled'),
('44556600-0000-4000-8000-000000000021','44556600-0000-4000-8000-000000000011','Foreign fixture job','reported');
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.owner_access',public.author_owner_property_access('44556600-0000-4000-8000-000000000030',null,0,'44556600-0000-4000-8000-000000000020',' Approved-Owner@example.invalid ',true,'Approved portfolio access',true)::text,true);

select set_config('openhouse.owner_asset',public.author_finance_account(gen_random_uuid(),'OWNER-A','Owner fixture asset','asset','Approved fixture chart',true)::text,true);
select set_config('openhouse.owner_income',public.author_finance_account(gen_random_uuid(),'OWNER-I','Owner fixture income','income','Approved fixture chart',true)::text,true);
select set_config('openhouse.owner_expense',public.author_finance_account(gen_random_uuid(),'OWNER-E','Owner fixture expense','expense','Approved fixture chart',true)::text,true);
select public.post_finance_journal(gen_random_uuid(),'JMD','Owner fixture journal','Approved fixture posting',true,jsonb_build_array(
jsonb_build_object('account_id',current_setting('openhouse.owner_asset'),'property_id','44556600-0000-4000-8000-000000000020','debit_minor',8000,'credit_minor',0),
jsonb_build_object('account_id',current_setting('openhouse.owner_expense'),'property_id','44556600-0000-4000-8000-000000000020','debit_minor',2001,'credit_minor',0),
jsonb_build_object('account_id',current_setting('openhouse.owner_income'),'property_id','44556600-0000-4000-8000-000000000020','debit_minor',0,'credit_minor',10001)));
set constraints all immediate;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ declare d date:=(now() at time zone 'America/Jamaica')::date;r jsonb;begin
 r:=public.owner_portfolio_summary(d,d,99999);
 if r->>'total'<>'1' or r->>'page'<>'1' or jsonb_array_length(r->'properties')<>1 or r#>>'{properties,0,posted_income_minor}'<>'10001' or r#>>'{properties,0,posted_expense_minor}'<>'2001' or r#>>'{properties,0,posted_net_minor}'<>'8000' or r#>>'{properties,0,managed_units}'<>'2' or r#>>'{properties,0,current_open_work_orders}'<>'1' or r->>'occupancy_available'<>'false' then raise exception 'Owner report totals/pagination failed: %',r;end if;
 if r#>'{properties,0,occupancy}' is distinct from 'null'::jsonb or (r->'properties'->0)?'organization_id' or (r->'properties'->0)?'reason' then raise exception 'Report disclosure failed';end if;
 r:=public.owner_portfolio_summary(d-1,d-1);if r#>>'{properties,0,posted_income_minor}'<>'0' then raise exception 'Jamaica cutoff failed';end if;
 begin perform public.owner_portfolio_summary(d,d-1);raise exception 'Invalid dates allowed';exception when invalid_parameter_value then null;end;
 begin perform public.owner_portfolio_summary(d-367,d);raise exception 'Unbounded dates allowed';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
set constraints all deferred;
do $$ declare lines jsonb;target uuid;begin
 select jsonb_agg(line order by n) into lines from (
 select n,jsonb_build_object('account_id',case when n<=100 then current_setting('openhouse.owner_asset') else current_setting('openhouse.owner_income') end,'property_id','44556600-0000-4000-8000-000000000020','debit_minor',case when n<=100 then 99999999999999 else 0 end,'credit_minor',case when n>100 then 99999999999999 else 0 end) line from generate_series(1,200)n)s;
 target:=public.post_finance_journal(gen_random_uuid(),'JMD','Owner large precision posting','Approved maximum fixture posting',true,lines);
 perform set_config('openhouse.owner_large',target::text,true);
end $$;
set constraints all immediate;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ declare d date:=(now() at time zone 'America/Jamaica')::date;r jsonb;begin
 r:=public.owner_portfolio_summary(d,d);if r#>>'{properties,0,posted_income_minor}'<>'10000000000009901' or r#>>'{properties,0,posted_net_minor}'<>'10000000000007900' then raise exception 'Large exact report failed: %',r;end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
set constraints all deferred;
select public.reverse_finance_journal(gen_random_uuid(),current_setting('openhouse.owner_large')::uuid,'Approved fixture reversal',true);
set constraints all immediate;
reset role;
do $$ declare n integer;target uuid;begin
 for n in 1..27 loop
 target:=gen_random_uuid();insert into public.properties(id,organization_id,name) values(target,'44556600-0000-4000-8000-000000000010','ZZ Portfolio fixture '||lpad(n::text,2,'0'));
 perform public.author_owner_property_access(gen_random_uuid(),null,0,target,'approved-owner@example.invalid',true,'Approved fixture portfolio',true);
 end loop;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ declare d date:=(now() at time zone 'America/Jamaica')::date;r jsonb;begin
 r:=public.owner_portfolio_summary(d,d);if r->>'total'<>'28' or jsonb_array_length(r->'properties')<>25 or r#>>'{properties,0,posted_income_minor}'<>'10001' or r#>>'{properties,0,posted_net_minor}'<>'8000' then raise exception 'Reversal/first page failed: %',r;end if;
 r:=public.owner_portfolio_summary(d,d,99999);if r->>'page'<>'2' or jsonb_array_length(r->'properties')<>3 then raise exception 'Last page/clamping failed';end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000004',true);
do $$ declare d date:=current_date;begin if public.owner_portfolio_summary(d,d)->>'total'<>'0' then raise exception 'Other account report exposed';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
select public.author_owner_property_access(gen_random_uuid(),(current_setting('openhouse.owner_access')::jsonb->>'id')::uuid,1,null,null,false,'Approved access withdrawal',true);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ declare d date:=current_date;begin if public.owner_portfolio_summary(d,d)->>'total'<>'27' then raise exception 'Revoked portfolio exposed';end if;end $$;
reset role;
update auth.users set email_confirmed_at=null where id='44556600-0000-4000-8000-000000000002';
set local role authenticated;
do $$ begin begin perform public.owner_portfolio_summary(current_date,current_date);raise exception 'Unverified report allowed';exception when insufficient_privilege then null;end;end $$;
rollback;
