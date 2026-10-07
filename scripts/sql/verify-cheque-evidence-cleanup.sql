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


select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
set local role authenticated;
select set_config('openhouse.invoice',public.manage_cheque_custody('44556600-0000-4000-8000-000000000040','receive',null,0,'44556600-0000-4000-8000-000000000020','Approved payer','Approved bank','CHQ-CLEANUP',10001,null,null,'Approved cheque intake',true)::text,true);
do $$ begin
 begin perform public.claim_expired_cheque_evidence();raise exception 'Client cleanup claim allowed';exception when insufficient_privilege then null;end;
 begin perform public.mark_cheque_evidence_purged(gen_random_uuid(),gen_random_uuid());raise exception 'Client purge marker allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
insert into public.cheque_bank_evidence(id,cheque_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,expires_at,withdrawn_at) values
('44556600-0000-4000-8000-000000000050',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000002',gen_random_uuid(),'deposit','expired.pdf','application/pdf',100,'fixture/expired.pdf','reserved',now()-interval '3 hours',null),
('44556600-0000-4000-8000-000000000051',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000002',gen_random_uuid(),'deposit','grace.pdf','application/pdf',100,'fixture/grace.pdf','reserved',now()-interval '1 hour',null),
('44556600-0000-4000-8000-000000000052',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000002',gen_random_uuid(),'deposit','withdraw.pdf','application/pdf',100,'fixture/withdraw.pdf','withdrawn',now()-interval '3 hours',now()-interval '2 hours');
insert into public.cheque_bank_evidence(id,cheque_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,expires_at,actual_size,sha256,uploaded_at) values
('44556600-0000-4000-8000-000000000053',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000002',gen_random_uuid(),'deposit','invoice.pdf','application/pdf',100,'fixture/invoice.pdf','uploaded',now()-interval '3 hours',100,repeat('a',64),now()-interval '3 hours');
insert into storage.objects(bucket_id,name,metadata) values('cheque-bank-evidence','fixture/withdraw.pdf','{"size":100}');
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
set local role authenticated;
select public.manage_cheque_custody(gen_random_uuid(),'record_deposit',(current_setting('openhouse.invoice')::jsonb->>'id')::uuid,1,null,null,null,null,null,'44556600-0000-4000-8000-000000000053','BANK-CLEANUP','Approved bank deposit',true);
reset role;
set local role service_role;
select set_config('openhouse.claims',(select jsonb_agg(to_jsonb(c))::text from public.claim_expired_cheque_evidence() c),true);
do $$ declare claims jsonb:=current_setting('openhouse.claims')::jsonb;nonce uuid;begin
 if jsonb_array_length(claims)<>2 then raise exception 'Cleanup eligibility changed';end if;
 if exists(select 1 from jsonb_array_elements(claims)c where c->>'id' not in('44556600-0000-4000-8000-000000000050','44556600-0000-4000-8000-000000000052')) then raise exception 'Grace/current/reviewed file claimed';end if;
 if exists(select 1 from public.claim_expired_cheque_evidence()) then raise exception 'Active claims reused';end if;
 select (c->>'claim_id')::uuid into nonce from jsonb_array_elements(claims)c where c->>'id'='44556600-0000-4000-8000-000000000050';
 if not public.mark_cheque_evidence_purged('44556600-0000-4000-8000-000000000050',nonce) then raise exception 'Missing-object purge failed';end if;
 if not public.mark_cheque_evidence_purged('44556600-0000-4000-8000-000000000050',nonce) then raise exception 'Purge retry failed';end if;
 select (c->>'claim_id')::uuid into nonce from jsonb_array_elements(claims)c where c->>'id'='44556600-0000-4000-8000-000000000052';
 perform set_config('openhouse.old_claim',nonce::text,true);
 begin perform public.mark_cheque_evidence_purged('44556600-0000-4000-8000-000000000052',nonce);raise exception 'Existing object marked purged';exception when unique_violation then null;end;
 begin perform public.mark_cheque_evidence_purged('44556600-0000-4000-8000-000000000052',gen_random_uuid());raise exception 'Wrong claim accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.cheque_bank_evidence_events where evidence_id='44556600-0000-4000-8000-000000000050' and event_name='expired' and actor_user_id is null)<>1 then raise exception 'Expiry audit missing or repeated';end if;
 if not exists(select 1 from public.cheque_bank_evidence where id='44556600-0000-4000-8000-000000000050' and state='expired' and purged_at is not null) then raise exception 'Expired marker missing';end if;
 if exists(select 1 from public.cheque_bank_evidence where id<>'44556600-0000-4000-8000-000000000050' and purged_at is not null) then raise exception 'Unremoved/protected marker changed';end if;
 if has_table_privilege('authenticated','private.cheque_evidence_cleanup_claims','SELECT') or has_table_privilege('service_role','public.cheque_bank_evidence','UPDATE') then raise exception 'Direct cleanup table access granted';end if;
end $$;
update private.cheque_evidence_cleanup_claims set claimed_at=now()-interval '6 minutes' where evidence_id='44556600-0000-4000-8000-000000000052';
set local role service_role;
do $$ begin
 begin perform public.mark_cheque_evidence_purged('44556600-0000-4000-8000-000000000052',current_setting('openhouse.old_claim')::uuid);raise exception 'Expired lease accepted';exception when unique_violation then null;end;
end $$;
select set_config('openhouse.reclaims',(select jsonb_agg(to_jsonb(c))::text from public.claim_expired_cheque_evidence() c),true);
do $$ declare claims jsonb:=current_setting('openhouse.reclaims')::jsonb;begin
 if jsonb_array_length(claims)<>1 or claims->0->>'id'<>'44556600-0000-4000-8000-000000000052' or claims->0->>'claim_id'=current_setting('openhouse.old_claim') then raise exception 'Expired lease not replaced';end if;
 begin perform public.mark_cheque_evidence_purged('44556600-0000-4000-8000-000000000052',current_setting('openhouse.old_claim')::uuid);raise exception 'Old lease accepted after replacement';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
set local role authenticated;
select set_config('openhouse.batch_invoice',public.manage_cheque_custody(gen_random_uuid(),'receive',null,0,'44556600-0000-4000-8000-000000000020','Approved payer','Approved bank','CHQ-BATCH',10001,null,null,'Approved batch receipt',true)::text,true);
reset role;
insert into public.cheque_bank_evidence(cheque_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,expires_at,withdrawn_at)
 select (current_setting('openhouse.batch_invoice')::jsonb->>'id')::uuid,'44556600-0000-4000-8000-000000000010','44556600-0000-4000-8000-000000000002',gen_random_uuid(),'deposit','batch.pdf','application/pdf',100,'fixture/batch/'||gen_random_uuid()::text||'.pdf','withdrawn',now()-interval '3 hours',now()-interval '2 hours' from generate_series(1,25);
set local role service_role;
do $$ begin
 if (select count(*) from public.claim_expired_cheque_evidence())<>20 then raise exception 'Batch cap failed';end if;
 if (select count(*) from public.claim_expired_cheque_evidence())<>5 then raise exception 'Claim exclusion/next batch failed';end if;
 if exists(select 1 from public.claim_expired_cheque_evidence()) then raise exception 'Already claimed batch reused';end if;
end $$;
reset role;
rollback;
