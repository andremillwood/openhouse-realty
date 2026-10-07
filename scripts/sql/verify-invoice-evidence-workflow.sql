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
select set_config('openhouse.evidence',public.reserve_invoice_evidence((current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000050','invoice','invoice.pdf','application/pdf',100)::text,true);
do $$ declare inv uuid:=(current_setting('openhouse.invoice')::jsonb->>'id')::uuid;doc jsonb:=current_setting('openhouse.evidence')::jsonb;begin
 if public.reserve_invoice_evidence(inv,'44556600-0000-4000-8000-000000000050','invoice','invoice.pdf','application/pdf',100)<>doc then raise exception 'Reservation retry changed';end if;
 if not private.invoice_evidence_storage_access(doc->>'path','insert') or not private.invoice_evidence_storage_access(doc->>'path','read') then raise exception 'Own reserved object denied';end if;
 if private.invoice_evidence_storage_access(doc->>'path','delete') then raise exception 'Object delete permitted';end if;
 begin perform public.reserve_invoice_evidence(inv,'44556600-0000-4000-8000-000000000050','supporting','invoice.pdf','application/pdf',100);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.reserve_invoice_evidence(inv,gen_random_uuid(),'invoice','../invoice.pdf','application/pdf',100);raise exception 'Path filename accepted';exception when invalid_parameter_value then null;end;
 begin perform public.reserve_invoice_evidence(inv,gen_random_uuid(),'invoice','invoice.pdf','application/pdf',8388609);raise exception 'Oversize accepted';exception when invalid_parameter_value then null;end;
 begin perform public.finish_invoice_evidence('44556600-0000-4000-8000-000000000003',(doc->>'id')::uuid,100,'application/pdf',repeat('a',64));raise exception 'Client certified evidence';exception when insufficient_privilege then null;end;
 insert into storage.objects(bucket_id,name,owner_id,metadata) values('vendor-invoice-evidence',doc->>'path','44556600-0000-4000-8000-000000000003','{"size":100,"mimetype":"application/pdf"}');
 begin insert into storage.objects(bucket_id,name) values('vendor-invoice-evidence','unreserved.pdf');raise exception 'Unreserved object insert allowed';exception when insufficient_privilege then null;end;
 update storage.objects set metadata='{"size":101}' where bucket_id='vendor-invoice-evidence' and name=doc->>'path';
 if found then raise exception 'Client overwrote object metadata';end if;
 begin
  delete from storage.objects where bucket_id='vendor-invoice-evidence' and name=doc->>'path';
  if found then raise exception 'Client removed object';end if;
 exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ declare doc jsonb:=current_setting('openhouse.evidence')::jsonb;begin
 if private.invoice_evidence_storage_access(doc->>'path','read') or private.invoice_evidence_storage_access(doc->>'path','insert') then raise exception 'Reviewer accessed reserved file';end if;
 if exists(select 1 from storage.objects where bucket_id='vendor-invoice-evidence') then raise exception 'Reserved Storage metadata exposed';end if;
 begin perform public.reserve_invoice_evidence((current_setting('openhouse.invoice')::jsonb->>'id')::uuid,gen_random_uuid(),'invoice','invoice.pdf','application/pdf',100);raise exception 'Reviewer uploaded for submitter';exception when insufficient_privilege then null;end;
 begin perform public.withdraw_invoice_evidence((doc->>'id')::uuid);raise exception 'Reviewer withdrew file';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role service_role;
do $$ declare doc jsonb:=current_setting('openhouse.evidence')::jsonb;begin
 begin perform public.finish_invoice_evidence('44556600-0000-4000-8000-000000000003',(doc->>'id')::uuid,101,'application/pdf',repeat('a',64));raise exception 'Wrong byte size accepted';exception when invalid_parameter_value then null;end;
 begin perform public.finish_invoice_evidence('44556600-0000-4000-8000-000000000002',(doc->>'id')::uuid,100,'application/pdf',repeat('a',64));raise exception 'Wrong actor certified';exception when insufficient_privilege then null;end;
 perform public.finish_invoice_evidence('44556600-0000-4000-8000-000000000003',(doc->>'id')::uuid,100,'application/pdf',repeat('a',64));
 perform public.finish_invoice_evidence('44556600-0000-4000-8000-000000000003',(doc->>'id')::uuid,100,'application/pdf',repeat('a',64));
 begin perform public.finish_invoice_evidence('44556600-0000-4000-8000-000000000003',(doc->>'id')::uuid,100,'application/pdf',repeat('b',64));raise exception 'Changed certification accepted';exception when unique_violation then null;end;
end $$;
reset role;
set local role authenticated;
do $$ declare doc jsonb:=current_setting('openhouse.evidence')::jsonb;begin
 if not private.invoice_evidence_storage_access(doc->>'path','read') or private.invoice_evidence_storage_access(doc->>'path','insert') then raise exception 'Certified Storage authority wrong';end if;
 if (select count(*) from storage.objects where bucket_id='vendor-invoice-evidence')<>1 then raise exception 'Reviewer certified Storage read failed';end if;
 if (select count(*) from public.vendor_invoice_evidence_events where evidence_id=(doc->>'id')::uuid)<>2 then raise exception 'Certification retry duplicated audit';end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000006',true);
do $$ begin if private.invoice_evidence_storage_access(current_setting('openhouse.evidence')::jsonb->>'path','read') then raise exception 'Foreign object access allowed';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
select set_config('openhouse.withdraw',public.reserve_invoice_evidence((current_setting('openhouse.invoice')::jsonb->>'id')::uuid,gen_random_uuid(),'supporting','support.pdf','application/pdf',100)::text,true);
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
do $$ begin
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'review',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,1,null,null,null,null,null,'Review with pending upload',true);raise exception 'Pending upload review permitted';exception when unique_violation then null;end;
 if (select count(*) from public.vendor_invoice_review_evidence)<>0 then raise exception 'Snapshot created before review';end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
select public.withdraw_invoice_evidence((current_setting('openhouse.withdraw')::jsonb->>'id')::uuid);
select public.withdraw_invoice_evidence((current_setting('openhouse.withdraw')::jsonb->>'id')::uuid);
do $$ begin if private.invoice_evidence_storage_access(current_setting('openhouse.withdraw')::jsonb->>'path','insert') then raise exception 'Withdrawn upload permitted';end if;end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
select public.manage_vendor_invoice(gen_random_uuid(),'review',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,1,null,null,null,null,null,'Independent invoice review',true);
do $$ begin
 if (select count(*) from public.vendor_invoice_review_evidence)<>1 or not exists(select 1 from public.vendor_invoice_review_evidence where evidence_id=(current_setting('openhouse.evidence')::jsonb->>'id')::uuid and kind='invoice' and sha256=repeat('a',64) and reviewed_version=2) then raise exception 'Certified review snapshot failed';end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.reserve_invoice_evidence((current_setting('openhouse.invoice')::jsonb->>'id')::uuid,gen_random_uuid(),'invoice','invoice.pdf','application/pdf',100);raise exception 'Upload after review permitted';exception when unique_violation then null;end;
 begin perform public.withdraw_invoice_evidence((current_setting('openhouse.evidence')::jsonb->>'id')::uuid);raise exception 'Withdrawal after review permitted';exception when unique_violation then null;end;
end $$;
reset role;
rollback;
