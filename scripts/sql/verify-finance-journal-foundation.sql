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
insert into public.finance_accounts(id,organization_id,code,name,account_class,approved_by,approval_reason) values
('33445500-0000-4000-8000-000000000020','33445500-0000-4000-8000-000000000010','TEST-A','Fixture asset','asset','33445500-0000-4000-8000-000000000001','Approved fixture account'),
('33445500-0000-4000-8000-000000000021','33445500-0000-4000-8000-000000000010','TEST-I','Fixture income','income','33445500-0000-4000-8000-000000000001','Approved fixture account'),
('33445500-0000-4000-8000-000000000022','33445500-0000-4000-8000-000000000011','TEST-F','Foreign asset','asset','33445500-0000-4000-8000-000000000004','Approved fixture account');
insert into public.finance_journals(id,organization_id,request_id,posted_by,memo,reason,payload,posted_at) values('33445500-0000-4000-8000-000000000030','33445500-0000-4000-8000-000000000010',gen_random_uuid(),'33445500-0000-4000-8000-000000000002','Balanced fixture posting','Reviewed test posting','{}','2000-01-01');
insert into public.finance_journal_lines(journal_id,organization_id,line_number,account_id,debit_minor,credit_minor) values
('33445500-0000-4000-8000-000000000030','33445500-0000-4000-8000-000000000010',1,'33445500-0000-4000-8000-000000000020',10001,0),
('33445500-0000-4000-8000-000000000030','33445500-0000-4000-8000-000000000010',2,'33445500-0000-4000-8000-000000000021',0,10001);
set constraints all immediate;
set constraints all deferred;
do $$ declare journal uuid;begin
 if exists(select 1 from public.finance_journals where posted_at<'2020-01-01' or created_transaction<>pg_current_xact_id()) then raise exception 'Server posting metadata spoofed';end if;
 begin
 insert into public.finance_journals(organization_id,request_id,posted_by,memo,reason,payload) values('33445500-0000-4000-8000-000000000010',gen_random_uuid(),'33445500-0000-4000-8000-000000000002','Unbalanced fixture posting','Reviewed test posting','{}') returning id into journal;
 insert into public.finance_journal_lines(journal_id,organization_id,line_number,account_id,debit_minor,credit_minor) values(journal,'33445500-0000-4000-8000-000000000010',1,'33445500-0000-4000-8000-000000000020',10001,0),(journal,'33445500-0000-4000-8000-000000000010',2,'33445500-0000-4000-8000-000000000021',0,10000);
 set constraints all immediate;raise exception 'One-cent imbalance accepted';exception when unique_violation then null;end;
 begin insert into public.finance_journals(organization_id,request_id,posted_by,memo,reason,payload) values('33445500-0000-4000-8000-000000000010',gen_random_uuid(),'33445500-0000-4000-8000-000000000002','Empty fixture posting','Reviewed test posting','{}');set constraints all immediate;raise exception 'Empty journal accepted';exception when unique_violation then null;end;
 begin insert into public.finance_journal_lines(journal_id,organization_id,line_number,account_id,debit_minor,credit_minor) values('33445500-0000-4000-8000-000000000030','33445500-0000-4000-8000-000000000010',3,'33445500-0000-4000-8000-000000000022',1,0);raise exception 'Foreign account binding allowed';exception when unique_violation then null;end;
 begin update public.finance_journals set memo='Rewritten journal';raise exception 'Journal rewritten';exception when unique_violation then null;end;
 begin delete from public.finance_journal_lines;raise exception 'Journal lines deleted';exception when unique_violation then null;end;
 begin update public.finance_accounts set name='Rewritten account';raise exception 'Account rewritten';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin
 if (select count(*) from public.finance_accounts)<>2 or (select count(*) from public.finance_journals)<>1 or (select count(*) from public.finance_journal_lines)<>2 then raise exception 'Finance scoped read failed';end if;
 begin insert into public.finance_journals(organization_id,request_id,posted_by,memo,reason,payload) values('33445500-0000-4000-8000-000000000010',gen_random_uuid(),auth.uid(),'Direct posting attempt','Unauthorized direct posting','{}');raise exception 'Finance bypassed posting RPC';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000003',true);
do $$ begin if exists(select 1 from public.finance_accounts) or exists(select 1 from public.finance_journals) or exists(select 1 from public.finance_journal_lines) then raise exception 'Manager read finance books';end if;end $$;
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000004',true);
do $$ begin if (select count(*) from public.finance_accounts)<>1 or exists(select 1 from public.finance_journals) or exists(select 1 from public.finance_journal_lines) then raise exception 'Foreign finance books exposed';end if;end $$;
reset role;
update auth.users set email_confirmed_at=null where id='33445500-0000-4000-8000-000000000002';
select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin if exists(select 1 from public.finance_journals) then raise exception 'Unverified finance read books';end if;end $$;
reset role;
set constraints all immediate;
rollback;
