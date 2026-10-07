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
do $$ declare r jsonb;begin
 r:=public.manage_vendor_invoice('44556600-0000-4000-8000-000000000040','submit',null,0,'44556600-0000-4000-8000-000000000020',null,'Approved Vendor','INV-1',10001,'Approved invoice intake',true);
 if r<>current_setting('openhouse.invoice')::jsonb or (select count(*) from public.vendor_invoice_reviews)<>1 then raise exception 'Invoice retry failed';end if;
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'submit',null,0,null,null,' approved vendor ','inv-1',10001,'Duplicate invoice intake',true);raise exception 'Duplicate allowed';exception when unique_violation then null;end;
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'submit',null,0,null,null,'Approved Vendor','INV-fraction',1.1,'Invalid fractional cents',true);raise exception 'Fraction allowed';exception when invalid_parameter_value then null;end;
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'submit',null,0,'44556600-0000-4000-8000-000000000021',null,'Approved Vendor','INV-foreign',10001,'Foreign invoice intake',true);raise exception 'Foreign property allowed';exception when insufficient_privilege then null;end;
 begin update public.reviewed_vendor_invoices set state='approved';raise exception 'Direct write allowed';exception when insufficient_privilege then null;end;
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'review',(r->>'id')::uuid,1,null,null,null,null,null,'Manager self review attempt',true);raise exception 'Manager review allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ declare id uuid:=(current_setting('openhouse.invoice')::jsonb->>'id')::uuid;begin
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'approve',id,1,null,null,null,null,null,'Approval without review',true);raise exception 'Premature approval allowed';exception when unique_violation then null;end;
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'review',id,1,null,null,null,null,null,'Review without source invoice',true);raise exception 'Review without source allowed';exception when unique_violation then null;end;
end $$;
reset role;
insert into public.vendor_invoice_evidence(id,invoice_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,actual_size,sha256,uploaded_at) values
('44556600-0000-4000-8000-000000000052',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000003',gen_random_uuid(),'supporting','support.pdf','application/pdf',100,'fixture/support.pdf','uploaded',100,repeat('b',64),now());
set local role authenticated;
do $$ begin
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'review',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,1,null,null,null,null,null,'Review supporting document only',true);raise exception 'Support-only review allowed';exception when unique_violation then null;end;
 if exists(select 1 from public.vendor_invoice_review_evidence) then raise exception 'Denied review left snapshot';end if;
end $$;
reset role;
insert into public.vendor_invoice_evidence(id,invoice_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,actual_size,sha256,uploaded_at) values
('44556600-0000-4000-8000-000000000053',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000003',gen_random_uuid(),'invoice','invoice.pdf','application/pdf',100,'fixture/invoice.pdf','uploaded',100,repeat('a',64),now());
set local role authenticated;
select public.manage_vendor_invoice('44556600-0000-4000-8000-000000000041','review',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,1,null,null,null,null,null,'Independent finance review',true);
do $$ begin
 if (select count(*) from public.vendor_invoice_review_evidence)<>2 or not exists(select 1 from public.vendor_invoice_review_evidence where kind='invoice' and sha256=repeat('a',64) and actual_size=100 and reviewed_version=2) then raise exception 'Review snapshot missing or changed';end if;
 perform public.manage_vendor_invoice('44556600-0000-4000-8000-000000000041','review',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,1,null,null,null,null,null,'Independent finance review',true);
 if (select count(*) from public.vendor_invoice_review_evidence)<>2 then raise exception 'Review retry duplicated snapshots';end if;
 begin update public.vendor_invoice_review_evidence set sha256=repeat('c',64);raise exception 'Client snapshot edited';exception when insufficient_privilege then null;end;
end $$;
do $$ declare id uuid:=(current_setting('openhouse.invoice')::jsonb->>'id')::uuid;begin
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'approve',id,2,null,null,null,null,null,'Same reviewer approval',true);raise exception 'Reviewer approval allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000001',true);
do $$ declare id uuid:=(current_setting('openhouse.invoice')::jsonb->>'id')::uuid;begin
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'approve',id,1,null,null,null,null,null,'Stale invoice approval',true);raise exception 'Stale allowed';exception when serialization_failure then null;end;
end $$;
select public.manage_vendor_invoice('44556600-0000-4000-8000-000000000042','approve',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,2,null,null,null,null,null,'Independent final approval',true);
do $$ begin
 if not exists(select 1 from public.reviewed_vendor_invoices where state='approved' and version=3 and reviewed_by='44556600-0000-4000-8000-000000000002' and approved_by='44556600-0000-4000-8000-000000000001' and amount_minor=10001) or (select count(*) from public.vendor_invoice_reviews)<>3 then raise exception 'Independent approval/audit failed';end if;
 if exists(select 1 from public.finance_journals where organization_id='44556600-0000-4000-8000-000000000010') then raise exception 'Approval posted finance';end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin if exists(select 1 from public.reviewed_vendor_invoices) or exists(select 1 from public.vendor_invoice_reviews) or exists(select 1 from public.vendor_invoice_review_evidence) then raise exception 'Foreign read allowed';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000005',true);
do $$ begin if exists(select 1 from public.reviewed_vendor_invoices) then raise exception 'Unverified read allowed';end if;end $$;
reset role;
do $$ begin
 begin update public.reviewed_vendor_invoices set amount_minor=999;raise exception 'Details changed';exception when unique_violation then null;end;
 begin delete from public.vendor_invoice_reviews;raise exception 'Audit deleted';exception when unique_violation then null;end;
 begin update public.properties set organization_id='44556600-0000-4000-8000-000000000011' where id='44556600-0000-4000-8000-000000000020';raise exception 'History property moved';exception when unique_violation then null;end;
 begin update public.vendor_invoice_review_evidence set sha256=repeat('c',64);raise exception 'Snapshot changed';exception when unique_violation then null;end;
 begin delete from public.vendor_invoice_review_evidence;raise exception 'Snapshot deleted';exception when unique_violation then null;end;
 begin update public.vendor_invoice_evidence set state='withdrawn' where state='uploaded';raise exception 'Frozen document withdrawn';exception when unique_violation then null;end;
 begin update public.vendor_invoice_evidence set purged_at=now() where state='uploaded';raise exception 'Current document purged';exception when unique_violation then null;end;
end $$;
rollback;
