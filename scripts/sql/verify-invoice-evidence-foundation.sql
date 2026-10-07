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
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
set local role authenticated;
select set_config('openhouse.invoice',public.manage_vendor_invoice('44556600-0000-4000-8000-000000000040','submit',null,0,'44556600-0000-4000-8000-000000000020',null,'Approved Vendor','INV-1',10001,'Approved invoice intake',true)::text,true);
reset role;
insert into public.vendor_invoice_evidence(id,invoice_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path) values('44556600-0000-4000-8000-000000000050',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000003',gen_random_uuid(),'invoice','invoice.pdf','application/pdf',100,'fixture/invoice.pdf');
set local role authenticated;
do $$ begin
 if (select count(*) from public.vendor_invoice_evidence)<>1 then raise exception 'Submitter reservation read failed';end if;
 begin update public.vendor_invoice_evidence set state='uploaded';raise exception 'Client certification allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.vendor_invoice_evidence) then raise exception 'Reviewer saw uncertified reservation';end if;end $$;
reset role;
do $$ begin
 begin update public.vendor_invoice_evidence set state='uploaded';raise exception 'Missing certification allowed';exception when check_violation then null;end;
 begin update public.vendor_invoice_evidence set file_name='other.pdf';raise exception 'Evidence identity changed';exception when unique_violation then null;end;
end $$;
update public.vendor_invoice_evidence set state='uploaded',actual_size=100,sha256=repeat('a',64),uploaded_at=now();
do $$ begin
 begin update public.vendor_invoice_evidence set sha256=repeat('b',64);raise exception 'Certified hash changed';exception when unique_violation then null;end;
 begin update public.vendor_invoice_evidence set uploaded_at=now()+interval '1 second';raise exception 'Certification time changed';exception when unique_violation then null;end;
 begin update public.vendor_invoice_evidence set state='reserved';raise exception 'Certified evidence reopened';exception when unique_violation then null;end;
 begin update public.vendor_invoice_evidence set state='expired';raise exception 'Certified evidence expired';exception when unique_violation then null;end;
end $$;
set local role authenticated;
do $$ begin if (select count(*) from public.vendor_invoice_evidence)<>1 then raise exception 'Finance uploaded metadata read failed';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin if exists(select 1 from public.vendor_invoice_evidence) then raise exception 'Foreign evidence metadata exposed';end if;end $$;
reset role;
do $$ begin
 if not exists(select 1 from storage.buckets where id='vendor-invoice-evidence' and not public and file_size_limit=8388608) then raise exception 'Private bucket constraints missing';end if;
 if has_table_privilege('authenticated','public.vendor_invoice_evidence','INSERT') or has_table_privilege('authenticated','public.vendor_invoice_evidence','UPDATE') then raise exception 'Direct client writes granted';end if;
end $$;
update public.vendor_invoice_evidence set state='withdrawn',withdrawn_at=now();
do $$ begin
 begin update public.vendor_invoice_evidence set state='uploaded';raise exception 'Withdrawn evidence revived';exception when unique_violation then null;end;
 begin update public.vendor_invoice_evidence set withdrawn_at=now()+interval '1 second';raise exception 'Withdrawal time changed';exception when unique_violation then null;end;
end $$;
rollback;
