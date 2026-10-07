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
do $$ declare inv uuid:=(current_setting('openhouse.invoice')::jsonb->>'id')::uuid;r jsonb;begin
 for n in 1..10 loop
  r:=public.reserve_invoice_evidence(inv,gen_random_uuid(),'supporting','support.pdf','application/pdf',100);
  if n=1 then perform set_config('openhouse.first_evidence',r::text,true);end if;
 end loop;
 begin perform public.reserve_invoice_evidence(inv,gen_random_uuid(),'invoice','invoice.pdf','application/pdf',100);raise exception 'Eleventh current file allowed';exception when unique_violation then null;end;
 perform public.withdraw_invoice_evidence((current_setting('openhouse.first_evidence')::jsonb->>'id')::uuid);
 r:=public.reserve_invoice_evidence(inv,'44556600-0000-4000-8000-000000000060','invoice','invoice.pdf','application/pdf',100);
 perform set_config('openhouse.retry',r::text,true);
end $$;
reset role;
insert into public.vendor_invoice_evidence(invoice_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,withdrawn_at)
 select (current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000003',gen_random_uuid(),'supporting','support.pdf','application/pdf',100,'fixture/daily/'||gen_random_uuid()::text||'.pdf','withdrawn',now() from generate_series(1,39);
set local role authenticated;
do $$ declare inv uuid:=(current_setting('openhouse.invoice')::jsonb->>'id')::uuid;begin
 if (select count(*) from public.vendor_invoice_evidence)<>50 then raise exception 'Daily fixture count wrong';end if;
 if public.reserve_invoice_evidence(inv,'44556600-0000-4000-8000-000000000060','invoice','invoice.pdf','application/pdf',100)<>current_setting('openhouse.retry')::jsonb then raise exception 'Quota blocked exact retry';end if;
 -- Release all live files so the next denial proves the daily bound separately.
 for inv in select id from public.vendor_invoice_evidence where state='reserved' loop perform public.withdraw_invoice_evidence(inv);end loop;
 begin perform public.reserve_invoice_evidence((current_setting('openhouse.invoice')::jsonb->>'id')::uuid,gen_random_uuid(),'invoice','invoice.pdf','application/pdf',100);raise exception 'Daily limit exceeded';exception when unique_violation then null;end;
end $$;
reset role;
insert into public.vendor_invoice_evidence(id,invoice_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,expires_at) values
('44556600-0000-4000-8000-000000000052',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000003','44556600-0000-4000-8000-000000000061','invoice','expired.pdf','application/pdf',100,'fixture/expired.pdf',now()-interval '1 minute');
set local role authenticated;
do $$ begin
 if private.invoice_evidence_storage_access('fixture/expired.pdf','read') or private.invoice_evidence_storage_access('fixture/expired.pdf','insert') then raise exception 'Expired object access allowed';end if;
 begin perform public.reserve_invoice_evidence((current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000061','invoice','expired.pdf','application/pdf',100);raise exception 'Expired reservation retry allowed';exception when unique_violation then null;end;
end $$;
reset role;
set local role service_role;
do $$ begin
 begin perform public.finish_invoice_evidence('44556600-0000-4000-8000-000000000003','44556600-0000-4000-8000-000000000052',100,'application/pdf',repeat('a',64));raise exception 'Expired file certified';exception when unique_violation then if sqlerrm<>'Reservation unavailable' then raise;end if;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
set local role authenticated;
select set_config('openhouse.rejection_request',gen_random_uuid()::text,true);
select set_config('openhouse.rejection',public.manage_vendor_invoice(current_setting('openhouse.rejection_request')::uuid,'reject',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,1,null,null,null,null,null,'Invoice documents insufficient',true)::text,true);
do $$ declare inv uuid:=(current_setting('openhouse.invoice')::jsonb->>'id')::uuid;begin
 if public.manage_vendor_invoice(current_setting('openhouse.rejection_request')::uuid,'reject',inv,1,null,null,null,null,null,'Invoice documents insufficient',true)<>current_setting('openhouse.rejection')::jsonb then raise exception 'Rejection retry changed';end if;
 begin perform public.manage_vendor_invoice(current_setting('openhouse.rejection_request')::uuid,'reject',inv,1,null,null,null,null,null,'Changed rejection explanation',true);raise exception 'Changed rejection retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'review',inv,2,null,null,null,null,null,'Review rejected invoice',true);raise exception 'Rejected invoice reviewed';exception when unique_violation then null;end;
 begin perform public.manage_vendor_invoice(gen_random_uuid(),'approve',inv,2,null,null,null,null,null,'Approve rejected invoice',true);raise exception 'Rejected invoice approved';exception when unique_violation then null;end;
 if (select count(*) from public.vendor_invoice_reviews)<>2 or exists(select 1 from public.vendor_invoice_review_evidence) then raise exception 'Rejection audit or evidence changed';end if;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.reserve_invoice_evidence((current_setting('openhouse.invoice')::jsonb->>'id')::uuid,gen_random_uuid(),'invoice','invoice.pdf','application/pdf',100);raise exception 'Rejected invoice upload allowed';exception when unique_violation then null;end;
end $$;
reset role;
rollback;
