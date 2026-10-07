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


insert into public.audited_cheque_receipts(id,organization_id,property_id,payer_name,bank_name,cheque_reference,amount_minor,received_by) values('44556600-0000-4000-8000-000000000030','44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000020','Fixture payer','Fixture bank','CHQ-EVIDENCE',10001,'44556600-0000-4000-8000-000000000002');

select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
set local role authenticated;
select set_config('openhouse.evidence',public.reserve_cheque_evidence('44556600-0000-4000-8000-000000000030','44556600-0000-4000-8000-000000000060','deposit','bank.pdf','application/pdf',100)::text,true);
do $$ begin
 if public.reserve_cheque_evidence('44556600-0000-4000-8000-000000000030','44556600-0000-4000-8000-000000000060','deposit','bank.pdf','application/pdf',100)<>current_setting('openhouse.evidence')::jsonb then raise exception 'Reservation retry changed';end if;
 begin perform public.reserve_cheque_evidence('44556600-0000-4000-8000-000000000030','44556600-0000-4000-8000-000000000060','clearance','bank.pdf','application/pdf',100);raise exception 'Changed reservation retry allowed';exception when invalid_parameter_value then null;end;
 if not private.cheque_evidence_storage_access(current_setting('openhouse.evidence')::jsonb->>'path','insert') then raise exception 'Own reservation insert denied';end if;
 begin perform public.finish_cheque_evidence(auth.uid(),(current_setting('openhouse.evidence')::jsonb->>'id')::uuid,100,'application/pdf',repeat('a',64));raise exception 'Client certification allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
do $$ begin if private.cheque_evidence_storage_access(current_setting('openhouse.evidence')::jsonb->>'path','insert') or private.cheque_evidence_storage_access(current_setting('openhouse.evidence')::jsonb->>'path','read') then raise exception 'Other staff reserved file access';end if;end $$;
reset role;
set local role service_role;
do $$ begin begin perform public.finish_cheque_evidence('44556600-0000-4000-8000-000000000002',(current_setting('openhouse.evidence')::jsonb->>'id')::uuid,100,'application/pdf',repeat('a',64));raise exception 'Missing object certified';exception when unique_violation then null;end;end $$;
reset role;
insert into storage.objects(bucket_id,name) values('cheque-bank-evidence',current_setting('openhouse.evidence')::jsonb->>'path');
set local role service_role;
select public.finish_cheque_evidence('44556600-0000-4000-8000-000000000002',(current_setting('openhouse.evidence')::jsonb->>'id')::uuid,100,'application/pdf',repeat('a',64));
select public.finish_cheque_evidence('44556600-0000-4000-8000-000000000002',(current_setting('openhouse.evidence')::jsonb->>'id')::uuid,100,'application/pdf',repeat('a',64));
reset role;
do $$ begin
 begin update public.cheque_bank_evidence set purged_at=statement_timestamp() where id=(current_setting('openhouse.evidence')::jsonb->>'id')::uuid;raise exception 'Current certified evidence purge allowed';exception when unique_violation then null;end;
 begin
  insert into public.cheque_bank_evidence_snapshots(event_id,cheque_id,evidence_id,organization_id,decision_version,kind,file_name,mime_type,sha256,actual_size,bank_reference)
  values(gen_random_uuid(),'44556600-0000-4000-8000-000000000030',(current_setting('openhouse.evidence')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010',2,'deposit','bank.pdf','application/pdf',repeat('a',64),100,'BANK-FIXTURE');
  raise exception 'Snapshot without audited bank decision allowed';
 exception when unique_violation then null;end;
 if has_table_privilege('authenticated','public.cheque_bank_evidence_snapshots','INSERT') or has_table_privilege('service_role','public.cheque_bank_evidence_snapshots','UPDATE') then raise exception 'Snapshot direct write grants open';end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
do $$ begin
 if not private.cheque_evidence_storage_access(current_setting('openhouse.evidence')::jsonb->>'path','read') or private.cheque_evidence_storage_access(current_setting('openhouse.evidence')::jsonb->>'path','insert') then raise exception 'Certified access/overwrite bounds wrong';end if;
 begin perform public.withdraw_cheque_evidence((current_setting('openhouse.evidence')::jsonb->>'id')::uuid);raise exception 'Other finance withdrew uploader evidence';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin if private.cheque_evidence_storage_access(current_setting('openhouse.evidence')::jsonb->>'path','read') then raise exception 'Foreign certified file access';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
select public.withdraw_cheque_evidence((current_setting('openhouse.evidence')::jsonb->>'id')::uuid);
select public.withdraw_cheque_evidence((current_setting('openhouse.evidence')::jsonb->>'id')::uuid);
select public.manage_cheque_custody(gen_random_uuid(),'cancel','44556600-0000-4000-8000-000000000030',1,null,null,null,null,null,null,null,'Approved cancellation after evidence withdrawal',true);
do $$ begin
 begin perform public.reserve_cheque_evidence('44556600-0000-4000-8000-000000000030',gen_random_uuid(),'deposit','bank.pdf','application/pdf',100);raise exception 'Closed cheque reservation allowed';exception when unique_violation then null;end;
 if private.cheque_evidence_storage_access(current_setting('openhouse.evidence')::jsonb->>'path','read') then raise exception 'Withdrawn file readable';end if;
end $$;
reset role;
do $$ begin if(select count(*) from public.cheque_bank_evidence_events)<>3 then raise exception 'Evidence retries duplicated history';end if;end $$;
rollback;
