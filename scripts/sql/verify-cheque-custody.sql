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
insert into public.staff_accounts(user_id,organization_id,role) values('44556600-0000-4000-8000-000000000002','44556600-0000-4000-8000-000000000010','finance');
insert into auth.users(id,email,email_confirmed_at) values
('44556600-0000-4000-8000-000000000007','staff-decline@example.invalid',now()),
('44556600-0000-4000-8000-000000000008','staff-expired@example.invalid',now()),
('44556600-0000-4000-8000-000000000009','staff-revoked@example.invalid',now()),
('44556600-0000-4000-8000-000000000012','staff-stale-admin@example.invalid',now()),
('44556600-0000-4000-8000-000000000014','second-admin@example.invalid',now());
insert into public.staff_accounts(user_id,organization_id,role) values('44556600-0000-4000-8000-000000000014','44556600-0000-4000-8000-000000000010','admin');

select set_config('openhouse.journals_before',(select count(*)::text from public.finance_journals),true);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
set local role authenticated;
select set_config('openhouse.cheque',public.manage_cheque_custody('44556600-0000-4000-8000-000000000060','receive',null,0,'44556600-0000-4000-8000-000000000020',' Approved payer ',' Approved bank ',' CHQ-101 ',10001,null,null,'Approved cheque custody receipt',true)::text,true);
do $$ begin
 if public.manage_cheque_custody('44556600-0000-4000-8000-000000000060','receive',null,0,'44556600-0000-4000-8000-000000000020','Approved payer','Approved bank','CHQ-101',10001,null,null,'Approved cheque custody receipt',true)<>current_setting('openhouse.cheque')::jsonb then raise exception 'Receive retry changed';end if;
 begin perform public.manage_cheque_custody('44556600-0000-4000-8000-000000000060','receive',null,0,'44556600-0000-4000-8000-000000000020','Approved payer','Approved bank','CHQ-101',10002,null,null,'Approved cheque custody receipt',true);raise exception 'Changed retry allowed';exception when invalid_parameter_value then null;end;
 begin perform public.manage_cheque_custody(gen_random_uuid(),'receive',null,0,'44556600-0000-4000-8000-000000000020','approved payer','approved bank','chq-101',10001,null,null,'Duplicate cheque custody receipt',true);raise exception 'Duplicate reference allowed';exception when unique_violation then null;end;
 begin perform public.manage_cheque_custody(gen_random_uuid(),'receive',null,0,'44556600-0000-4000-8000-000000000021','Approved payer','Approved bank','CHQ-102',10001,null,null,'Foreign cheque custody receipt',true);raise exception 'Foreign property allowed';exception when insufficient_privilege then null;end;
 begin perform public.manage_cheque_custody(gen_random_uuid(),'receive',null,0,'44556600-0000-4000-8000-000000000020','Approved payer','Approved bank','CHQ-102',10001.2,null,null,'Fractional cheque custody receipt',true);raise exception 'Fractional amount allowed';exception when invalid_parameter_value then null;end;
 begin update public.audited_cheque_receipts set state='cancelled';raise exception 'Direct state edit allowed';exception when insufficient_privilege then null;end;
 begin perform public.manage_cheque_custody(gen_random_uuid(),'confirm_clear',(current_setting('openhouse.cheque')::jsonb->>'id')::uuid,1,null,null,null,null,null,gen_random_uuid(),'BANK-101','Premature bank confirmation',true);raise exception 'Clearance before deposit allowed';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
do $$ begin
 if exists(select 1 from public.audited_cheque_receipts) or exists(select 1 from public.cheque_custody_events) then raise exception 'Manager read finance custody';end if;
 begin perform public.manage_cheque_custody(gen_random_uuid(),'receive',null,0,'44556600-0000-4000-8000-000000000020','Approved payer','Approved bank','CHQ-102',10001,null,null,'Manager cheque custody receipt',true);raise exception 'Manager received cheque';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin
 if exists(select 1 from public.audited_cheque_receipts) then raise exception 'Foreign custody exposed';end if;
 begin perform public.manage_cheque_custody(gen_random_uuid(),'cancel',(current_setting('openhouse.cheque')::jsonb->>'id')::uuid,1,null,null,null,null,null,null,null,'Foreign custody cancellation',true);raise exception 'Foreign cancellation allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ begin
 begin perform public.manage_cheque_custody(gen_random_uuid(),'cancel',(current_setting('openhouse.cheque')::jsonb->>'id')::uuid,2,null,null,null,null,null,null,null,'Stale custody cancellation',true);raise exception 'Stale cancellation allowed';exception when serialization_failure then null;end;
 begin perform public.manage_cheque_custody(gen_random_uuid(),'cancel',(current_setting('openhouse.cheque')::jsonb->>'id')::uuid,1,null,null,null,null,null,null,null,'Unapproved custody cancellation',false);raise exception 'Consent absent';exception when invalid_parameter_value then null;end;
end $$;
select set_config('openhouse.cancelled',public.manage_cheque_custody('44556600-0000-4000-8000-000000000061','cancel',(current_setting('openhouse.cheque')::jsonb->>'id')::uuid,1,null,null,null,null,null,null,null,'Approved custody cancellation',true)::text,true);
do $$ begin
 if public.manage_cheque_custody('44556600-0000-4000-8000-000000000061','cancel',(current_setting('openhouse.cheque')::jsonb->>'id')::uuid,1,null,null,null,null,null,null,null,'Approved custody cancellation',true)<>current_setting('openhouse.cancelled')::jsonb then raise exception 'Cancellation retry changed';end if;
 if(select count(*) from public.cheque_custody_events)<>2 then raise exception 'Custody audit duplicated';end if;
end $$;
reset role;
do $$ begin
 if(select count(*) from public.finance_journals)::text<>current_setting('openhouse.journals_before') then raise exception 'Custody unexpectedly posted journal';end if;
 begin update public.audited_cheque_receipts set amount_minor=10002;raise exception 'Receipt amount mutated';exception when unique_violation then null;end;
 begin update public.audited_cheque_receipts set state='received',cancelled_at=null,version=3;raise exception 'Cancelled receipt revived';exception when unique_violation then null;end;
 begin update public.properties set organization_id='44556600-0000-4000-8000-000000000011' where id='44556600-0000-4000-8000-000000000020';raise exception 'Custody property moved organization';exception when unique_violation then null;end;
 begin delete from public.cheque_custody_events;raise exception 'Custody audit deleted';exception when unique_violation then null;end;
end $$;
set local role service_role;
do $$ begin begin update public.audited_cheque_receipts set version=99;raise exception 'Service directly edited custody';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
