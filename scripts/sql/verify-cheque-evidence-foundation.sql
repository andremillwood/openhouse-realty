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
insert into public.cheque_bank_evidence(id,cheque_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path) values('44556600-0000-4000-8000-000000000040','44556600-0000-4000-8000-000000000030','44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000002',gen_random_uuid(),'deposit','bank.pdf','application/pdf',100,'fixture/bank.pdf');
insert into public.cheque_bank_evidence_events(evidence_id,actor_user_id,event_name) values('44556600-0000-4000-8000-000000000040','44556600-0000-4000-8000-000000000002','reserved');
do $$ begin
 if not exists(select 1 from storage.buckets where id='cheque-bank-evidence' and not public and file_size_limit=8388608) then raise exception 'Private bank bucket incorrect';end if;
 begin update public.cheque_bank_evidence set state='uploaded';raise exception 'Missing certification accepted';exception when check_violation then null;end;
 begin update public.cheque_bank_evidence set object_path='replacement.pdf';raise exception 'Evidence path changed';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin if exists(select 1 from public.cheque_bank_evidence) then raise exception 'Other finance reservation exposed';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ begin
 if(select count(*) from public.cheque_bank_evidence)<>1 then raise exception 'Own reservation hidden';end if;
 begin update public.cheque_bank_evidence set state='uploaded';raise exception 'Client certification allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
update public.cheque_bank_evidence set state='uploaded',sha256=repeat('a',64),actual_size=100,uploaded_at=now();
do $$ begin
 begin update public.cheque_bank_evidence set sha256=repeat('b',64);raise exception 'Certified hash changed';exception when unique_violation then null;end;
 begin update public.cheque_bank_evidence set state='reserved';raise exception 'Uploaded evidence reopened';exception when unique_violation then null;end;
 begin delete from public.cheque_bank_evidence_events;raise exception 'Evidence audit deleted';exception when unique_violation then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
do $$ begin if(select count(*) from public.cheque_bank_evidence)<>1 then raise exception 'Finance certified evidence hidden';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
do $$ begin if exists(select 1 from public.cheque_bank_evidence) or exists(select 1 from public.cheque_bank_evidence_events) then raise exception 'Manager evidence exposed';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin if exists(select 1 from public.cheque_bank_evidence) then raise exception 'Foreign evidence exposed';end if;end $$;
reset role;
update public.cheque_bank_evidence set state='withdrawn',withdrawn_at=now();
do $$ begin
 begin update public.cheque_bank_evidence set state='uploaded';raise exception 'Withdrawn evidence revived';exception when unique_violation then null;end;
 begin update public.cheque_bank_evidence set uploaded_at=now()+interval '1 hour';raise exception 'Terminal certification changed';exception when unique_violation then null;end;
end $$;
rollback;
