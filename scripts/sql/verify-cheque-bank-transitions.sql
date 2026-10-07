begin;
select set_config('openhouse.cheque_journal_count',(select count(*)::text from public.finance_journals),true);
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


insert into public.audited_cheque_receipts(id,organization_id,property_id,payer_name,bank_name,cheque_reference,amount_minor,received_by) values('44556600-0000-4000-8000-000000000030','44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000020','Fixture payer','Fixture bank','CHQ-EVIDENCE',10001,'44556600-0000-4000-8000-000000000002');

-- Trusted fixture metadata only; no real Storage bytes or bank confirmation.
insert into public.cheque_bank_evidence(id,cheque_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,sha256,actual_size,uploaded_at)
select ('44556600-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'44556600-0000-4000-8000-000000000030','44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000002',gen_random_uuid(),k,'bank.pdf','application/pdf',100,'fixture-bank/'||n,'uploaded',repeat('a',64),100,now()
from (values(70,'deposit'),(71,'clearance'),(72,'return')) f(n,k);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin
 begin perform public.manage_cheque_custody(gen_random_uuid(),'confirm_clear','44556600-0000-4000-8000-000000000030',1,null,null,null,null,null,'44556600-0000-4000-8000-000000000071','BANK-CLEAR','Approved bank clearance',true);raise exception 'Clear before deposit allowed';exception when unique_violation then null;end;
 begin perform public.manage_cheque_custody(gen_random_uuid(),'record_deposit','44556600-0000-4000-8000-000000000030',1,null,null,null,null,null,'44556600-0000-4000-8000-000000000071','BANK-DEPOSIT','Approved bank deposit',true);raise exception 'Wrong kind allowed';exception when unique_violation then null;end;
end $$;
select public.manage_cheque_custody('44556600-0000-4000-8000-000000000080','record_deposit','44556600-0000-4000-8000-000000000030',1,null,null,null,null,null,'44556600-0000-4000-8000-000000000070','BANK-DEPOSIT','Approved bank deposit',true);
select public.manage_cheque_custody('44556600-0000-4000-8000-000000000080','record_deposit','44556600-0000-4000-8000-000000000030',1,null,null,null,null,null,'44556600-0000-4000-8000-000000000070','BANK-DEPOSIT','Approved bank deposit',true);
do $$ begin
 if (select count(*) from public.cheque_bank_evidence_snapshots)<>1 then raise exception 'Deposit retry duplicated snapshot';end if;
 begin perform public.withdraw_cheque_evidence('44556600-0000-4000-8000-000000000070');raise exception 'Frozen deposit withdrawn';exception when unique_violation then null;end;
 begin perform public.manage_cheque_custody('44556600-0000-4000-8000-000000000080','record_deposit','44556600-0000-4000-8000-000000000030',1,null,null,null,null,null,'44556600-0000-4000-8000-000000000070','CHANGED-BANK','Approved bank deposit',true);raise exception 'Changed bank retry allowed';exception when invalid_parameter_value then null;end;
 begin perform public.manage_cheque_custody(gen_random_uuid(),'confirm_clear','44556600-0000-4000-8000-000000000030',1,null,null,null,null,null,'44556600-0000-4000-8000-000000000071','BANK-CLEAR','Approved bank clearance',true);raise exception 'Stale bank revision allowed';exception when serialization_failure then null;end;
end $$;
select public.manage_cheque_custody(gen_random_uuid(),'confirm_clear','44556600-0000-4000-8000-000000000030',2,null,null,null,null,null,'44556600-0000-4000-8000-000000000071','BANK-CLEAR','Approved bank clearance',true);
select public.manage_cheque_custody(gen_random_uuid(),'record_return','44556600-0000-4000-8000-000000000030',3,null,null,null,null,null,'44556600-0000-4000-8000-000000000072','BANK-RETURN','Approved bank return',true);
do $$ begin
 if (select count(*) from public.cheque_bank_evidence_snapshots)<>3 or (select version from public.audited_cheque_receipts where id='44556600-0000-4000-8000-000000000030')<>4 then raise exception 'Bank history incomplete';end if;
 begin perform public.manage_cheque_custody(gen_random_uuid(),'record_deposit','44556600-0000-4000-8000-000000000030',4,null,null,null,null,null,'44556600-0000-4000-8000-000000000070','BANK-AGAIN','Approved repeated deposit',true);raise exception 'Returned cheque revived';exception when unique_violation then null;end;
end $$;
-- A return can also follow deposit directly, without recording clearance.
reset role;
insert into public.audited_cheque_receipts(id,organization_id,property_id,payer_name,bank_name,cheque_reference,amount_minor,received_by)
values('44556600-0000-4000-8000-000000000031','44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000020','Fixture payer','Fixture bank','CHQ-RETURN-DIRECT',10001,'44556600-0000-4000-8000-000000000002');
insert into public.cheque_bank_evidence(id,cheque_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,sha256,actual_size,uploaded_at)
select ('44556600-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'44556600-0000-4000-8000-000000000031','44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000001',gen_random_uuid(),k,'bank.pdf','application/pdf',100,'fixture-bank/'||n,'uploaded',repeat('b',64),100,now()
from (values(73,'deposit'),(74,'return')) f(n,k);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
set local role authenticated;
select set_config('openhouse.pending_bank',public.reserve_cheque_evidence('44556600-0000-4000-8000-000000000031',gen_random_uuid(),'deposit','pending.pdf','application/pdf',100)::text,true);
do $$ begin
 begin perform public.manage_cheque_custody(gen_random_uuid(),'record_deposit','44556600-0000-4000-8000-000000000031',1,null,null,null,null,null,'44556600-0000-4000-8000-000000000073','BANK-PENDING','Approved deposit with pending upload',true);raise exception 'Pending upload decision allowed';exception when unique_violation then null;end;
 if (select version from public.audited_cheque_receipts where id='44556600-0000-4000-8000-000000000031')<>1 then raise exception 'Failed pending decision advanced revision';end if;
end $$;
select public.withdraw_cheque_evidence((current_setting('openhouse.pending_bank')::jsonb->>'id')::uuid);
select public.manage_cheque_custody(gen_random_uuid(),'record_deposit','44556600-0000-4000-8000-000000000031',1,null,null,null,null,null,'44556600-0000-4000-8000-000000000073','BANK-DIRECT-DEPOSIT','Approved cross-finance evidence deposit',true);
select public.manage_cheque_custody(gen_random_uuid(),'record_return','44556600-0000-4000-8000-000000000031',2,null,null,null,null,null,'44556600-0000-4000-8000-000000000074','BANK-DIRECT-RETURN','Approved direct bank return',true);
do $$ begin
 if not exists(select 1 from public.audited_cheque_receipts where id='44556600-0000-4000-8000-000000000031' and state='returned' and version=3) then raise exception 'Direct returned state missing';end if;
 if (select count(*) from public.cheque_bank_evidence_snapshots where cheque_id='44556600-0000-4000-8000-000000000031')<>2 then raise exception 'Direct return snapshots missing';end if;
end $$;
reset role;
insert into public.staff_accounts(user_id,organization_id,role) values('44556600-0000-4000-8000-000000000005','44556600-0000-4000-8000-000000000010','finance');
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000005',true);
set local role authenticated;
do $$ begin
 begin perform public.manage_cheque_custody(gen_random_uuid(),'record_return','44556600-0000-4000-8000-000000000031',3,null,null,null,null,null,'44556600-0000-4000-8000-000000000074','BANK-UNVERIFIED','Unverified finance decision',true);raise exception 'Unverified finance bank decision allowed';exception when insufficient_privilege then null;end;
 if exists(select 1 from public.cheque_bank_evidence_snapshots) then raise exception 'Unverified finance snapshots visible';end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin if exists(select 1 from public.cheque_bank_evidence_snapshots) then raise exception 'Foreign bank snapshots visible';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
do $$ begin if exists(select 1 from public.cheque_bank_evidence_snapshots) then raise exception 'Manager bank snapshots visible';end if;end $$;
reset role;
do $$ begin
 begin update public.cheque_bank_evidence_snapshots set bank_reference='CHANGED';raise exception 'Bank snapshot editable';exception when unique_violation then null;end;
 begin delete from public.cheque_bank_evidence where id='44556600-0000-4000-8000-000000000070';raise exception 'Frozen bank evidence removable';exception when unique_violation then null;end;
end $$;
do $$ begin if (select count(*) from public.finance_journals)<>current_setting('openhouse.cheque_journal_count')::bigint then raise exception 'Custody posted accounting journal';end if;end $$;
rollback;
