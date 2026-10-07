begin;
insert into auth.users(id,email,email_confirmed_at) values
('22334400-0000-4000-8000-000000000001','contractor-manager@example.invalid',now()),
('22334400-0000-4000-8000-000000000002','contractor-target@example.invalid',now()),
('22334400-0000-4000-8000-000000000003','contractor-unverified@example.invalid',null),
('22334400-0000-4000-8000-000000000004','contractor-foreign@example.invalid',now()),
('22334400-0000-4000-8000-000000000005','contractor-realtor@example.invalid',now()),
('22334400-0000-4000-8000-000000000006','contractor-prospect@example.invalid',now());
insert into public.organizations(id,name) values('22334400-0000-4000-8000-000000000007','Contractor fixtures'),('22334400-0000-4000-8000-000000000008','Foreign contractor fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
('22334400-0000-4000-8000-000000000001','22334400-0000-4000-8000-000000000007','manager'),
('22334400-0000-4000-8000-000000000003','22334400-0000-4000-8000-000000000007','manager'),
('22334400-0000-4000-8000-000000000004','22334400-0000-4000-8000-000000000008','manager'),
('22334400-0000-4000-8000-000000000005','22334400-0000-4000-8000-000000000007','realtor');

insert into public.properties(id,organization_id,name) values('22334400-0000-4000-8000-000000000010','22334400-0000-4000-8000-000000000007','Presence property');
insert into public.contractor_accounts(id,organization_id,user_id,company_name,trade_coverage,is_active,version) values('22334400-0000-4000-8000-000000000011','22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000002','Approved Contractor',array['Plumbing'],true,1);
insert into public.work_orders(id,organization_id,property_id,title,description,status,priority,revision,scheduled_start,scheduled_end) values('22334400-0000-4000-8000-000000000012','22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000010','Scheduled fixture','Approved work description for scheduled fixture.','scheduled','standard',3,now()-interval '1 hour',now()+interval '1 hour');
insert into public.contractor_work_offers(id,organization_id,work_order_id,contractor_id,company_name_snapshot,job_title,scope_summary,trade,work_version,state,expires_at) values('22334400-0000-4000-8000-000000000013','22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000012','22334400-0000-4000-8000-000000000011','Approved Contractor','Approved job','Approved plumbing scope for presence fixture.','Plumbing',3,'accepted',now()+interval '1 day');
insert into public.contractor_visits(id,organization_id,offer_id,contractor_user_id,property_id,starts_at,ends_at,shared_note,state) values('22334400-0000-4000-8000-000000000014','22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000013','22334400-0000-4000-8000-000000000002','22334400-0000-4000-8000-000000000010',now()-interval '1 hour',now()+interval '1 hour','Approved appointment note','confirmed');
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.security',public.author_property_security_assignment(gen_random_uuid(),null,0,'22334400-0000-4000-8000-000000000010','contractor-prospect@example.invalid',true,'Approved independent security',true)->>'id',true);
select set_config('openhouse.future_permit',public.manage_entry_permit(gen_random_uuid(),'authorize',null,'22334400-0000-4000-8000-000000000014',0,1,now()+interval '30 minutes',now()+interval '1 hour','Meet property security','Approved access authority confirmed',true)->>'id',true);
do $$ begin begin perform public.record_contractor_presence(gen_random_uuid(),'check_in',current_setting('openhouse.future_permit')::uuid,null,0,true,'Manager bypass entry');raise exception 'Unassigned manager checked in';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000006',true);
do $$ begin begin perform public.record_contractor_presence(gen_random_uuid(),'check_in',current_setting('openhouse.future_permit')::uuid,null,0,true,'Identity checked early');raise exception 'Early entry accepted';exception when unique_violation then null;end;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
select public.manage_entry_permit(gen_random_uuid(),'revoke',current_setting('openhouse.future_permit')::uuid,null,1,null,null,null,null,'Withdraw future access window',null);
select set_config('openhouse.permit',public.manage_entry_permit(gen_random_uuid(),'authorize',null,'22334400-0000-4000-8000-000000000014',0,1,now()-interval '30 minutes',now()+interval '30 minutes','Meet property security','Approved access authority confirmed',true)->>'id',true);
select set_config('openhouse.dual_security',public.author_property_security_assignment(gen_random_uuid(),null,0,'22334400-0000-4000-8000-000000000010','contractor-target@example.invalid',true,'Approved separate security role',true)->>'id',true);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
do $$ begin begin perform public.record_contractor_presence(gen_random_uuid(),'check_in',current_setting('openhouse.permit')::uuid,null,0,true,'Self identity check at gate');raise exception 'Dual-role self entry accepted';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
select public.author_property_security_assignment(gen_random_uuid(),current_setting('openhouse.dual_security')::uuid,1,null,null,false,'Withdraw dual security coverage',true);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000006',true);
do $$ begin begin perform public.record_contractor_presence(gen_random_uuid(),'check_in',current_setting('openhouse.permit')::uuid,null,0,false,'No identity check');raise exception 'Identity check absent';exception when invalid_parameter_value then null;end;end $$;
select set_config('openhouse.presence',public.record_contractor_presence('22334400-0000-4000-8000-000000000020','check_in',current_setting('openhouse.permit')::uuid,null,0,true,'Identity checked at gate')->>'id',true);
select public.record_contractor_presence('22334400-0000-4000-8000-000000000020','check_in',current_setting('openhouse.permit')::uuid,null,0,true,'Identity checked at gate');
do $$ begin
 if(select count(*) from public.contractor_presence)<>1 or(select count(*) from public.contractor_presence_changes)<>1 then raise exception 'Entry retry duplicated';end if;
 if exists(select 1 from public.work_orders) then raise exception 'Security internal work exposed';end if;
 begin perform public.record_contractor_presence(gen_random_uuid(),'check_out',null,current_setting('openhouse.presence')::uuid,2,null,'Stale departure response');raise exception 'Stale departure accepted';exception when serialization_failure then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
do $$ begin if(select count(*) from public.contractor_presence)<>1 or exists(select 1 from public.contractor_presence_changes) then raise exception 'Contractor presence privacy';end if;begin perform public.record_contractor_presence(gen_random_uuid(),'check_out',null,current_setting('openhouse.presence')::uuid,1,null,'Self recorded departure');raise exception 'Contractor self checked out';exception when insufficient_privilege then null;end;end $$;
do $$ begin begin perform public.manage_completion_report(gen_random_uuid(),'submit','22334400-0000-4000-8000-000000000013',null,3,0,'Replaced leaking valve and resealed the plumbing connection.','Pressure tested for thirty minutes.','No outstanding defects reported.',null,'Submit before departure',null);raise exception 'On-site report accepted';exception when unique_violation then null;end;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
do $$ begin if not exists(select 1 from public.work_orders where id='22334400-0000-4000-8000-000000000012' and status='on_site' and revision=4) then raise exception 'On-site transition failed';end if;end $$;
select public.manage_entry_permit(gen_random_uuid(),'revoke',current_setting('openhouse.permit')::uuid,null,1,null,null,null,null,'Revoke access while on site',null);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000006',true);
select public.record_contractor_presence('22334400-0000-4000-8000-000000000021','check_out',null,current_setting('openhouse.presence')::uuid,1,null,'Confirmed departure after revocation');
select public.record_contractor_presence('22334400-0000-4000-8000-000000000021','check_out',null,current_setting('openhouse.presence')::uuid,1,null,'Confirmed departure after revocation');
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
do $$ begin if not exists(select 1 from public.work_orders where id='22334400-0000-4000-8000-000000000012' and status='in_progress' and revision=5) or not exists(select 1 from public.contractor_presence where id=current_setting('openhouse.presence')::uuid and state='exited' and version=2 and checked_out_at is not null) or(select count(*) from public.contractor_presence_changes)<>2 then raise exception 'Departure transition/retry failed';end if;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
select set_config('openhouse.evidence',public.reserve_contractor_evidence('22334400-0000-4000-8000-000000000013','22334400-0000-4000-8000-000000000040','Completed valve.jpg','image/jpeg',10)->>'id',true);
select public.reserve_contractor_evidence('22334400-0000-4000-8000-000000000013','22334400-0000-4000-8000-000000000040','Completed valve.jpg','image/jpeg',10);
do $$ begin
 if(select count(*) from public.contractor_evidence)<>1 then raise exception 'Reservation retry duplicated';end if;
 begin perform public.finish_contractor_evidence('22334400-0000-4000-8000-000000000002',current_setting('openhouse.evidence')::uuid,10,'image/jpeg',repeat('a',64));raise exception 'Client certified evidence';exception when insufficient_privilege then null;end;
 begin perform public.reserve_contractor_evidence('22334400-0000-4000-8000-000000000013','22334400-0000-4000-8000-000000000040','Changed.jpg','image/jpeg',10);raise exception 'Changed reservation retry';exception when invalid_parameter_value then null;end;
end $$;
insert into storage.objects(bucket_id,name) select 'contractor-evidence',object_path from public.contractor_evidence where id=current_setting('openhouse.evidence')::uuid;
do $$ begin
 if not exists(select 1 from storage.objects where bucket_id='contractor-evidence') then raise exception 'Own reserved storage metadata unreadable';end if;
 begin insert into storage.objects(bucket_id,name) values('contractor-evidence','unreserved.jpg');raise exception 'Unreserved storage insert';exception when insufficient_privilege then null;end;
 if not private.contractor_evidence_storage_access((select object_path from public.contractor_evidence where id=current_setting('openhouse.evidence')::uuid),'insert') then raise exception 'Reserved storage access failed';end if;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
do $$ begin if exists(select 1 from public.contractor_evidence) or exists(select 1 from storage.objects where bucket_id='contractor-evidence') then raise exception 'Management reserved file exposed';end if;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
reset role;
set local role service_role;
select public.finish_contractor_evidence('22334400-0000-4000-8000-000000000002',current_setting('openhouse.evidence')::uuid,10,'image/jpeg',repeat('a',64));
select public.finish_contractor_evidence('22334400-0000-4000-8000-000000000002',current_setting('openhouse.evidence')::uuid,10,'image/jpeg',repeat('a',64));
reset role;
set local role authenticated;
select set_config('openhouse.offer_version',(select version::text from public.contractor_work_offers where id='22334400-0000-4000-8000-000000000013'),true);
select set_config('openhouse.report',public.manage_completion_report('22334400-0000-4000-8000-000000000030','submit','22334400-0000-4000-8000-000000000013',null,current_setting('openhouse.offer_version')::integer,0,'Replaced leaking valve and resealed the plumbing connection.','Pressure tested for thirty minutes.','No outstanding defects reported.',null,'Submitted completed work report',null)->>'id',true);
select public.manage_completion_report('22334400-0000-4000-8000-000000000030','submit','22334400-0000-4000-8000-000000000013',null,current_setting('openhouse.offer_version')::integer,0,'Replaced leaking valve and resealed the plumbing connection.','Pressure tested for thirty minutes.','No outstanding defects reported.',null,'Submitted completed work report',null);
do $$ begin
 if(select count(*) from public.contractor_completion_reports)<>1 or exists(select 1 from public.contractor_completion_changes) then raise exception 'Contractor evidence privacy/retry';end if;
 begin perform public.manage_completion_report(gen_random_uuid(),'approve',null,current_setting('openhouse.report')::uuid,null,1,null,null,null,'Work accepted after inspection.','Self approval attempt',true);raise exception 'Contractor self approval';exception when insufficient_privilege then null;end;
 begin perform public.manage_completion_report('22334400-0000-4000-8000-000000000030','submit','22334400-0000-4000-8000-000000000013',null,current_setting('openhouse.offer_version')::integer,0,'Changed report summary that must not reuse request.','Pressure tested for thirty minutes.','No outstanding defects reported.',null,'Submitted completed work report',null);raise exception 'Changed retry allowed';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
do $$ begin
 begin perform public.manage_completion_report(gen_random_uuid(),'approve',null,current_setting('openhouse.report')::uuid,null,2,null,null,null,'Work accepted after inspection.','Stale manager approval',true);raise exception 'Stale report accepted';exception when serialization_failure then null;end;
 begin perform public.manage_completion_report(gen_random_uuid(),'approve',null,current_setting('openhouse.report')::uuid,null,1,null,null,null,'Work accepted after inspection.','Missing evidence review',false);raise exception 'Evidence review absent';exception when invalid_parameter_value then null;end;
end $$;
do $$ begin if not exists(select 1 from public.contractor_evidence) or not exists(select 1 from storage.objects where bucket_id='contractor-evidence') then raise exception 'Manager verified upload unreadable';end if;end $$;
do $$ begin if not exists(select 1 from public.contractor_report_evidence where report_id=current_setting('openhouse.report')::uuid and evidence_id=current_setting('openhouse.evidence')::uuid) then raise exception 'Evidence not frozen';end if;end $$;
select public.manage_completion_report(gen_random_uuid(),'request_changes',null,current_setting('openhouse.report')::uuid,null,1,null,null,null,'Please document the final pressure readings.','Requested test result detail',null);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
do $$ begin begin perform public.withdraw_contractor_evidence(current_setting('openhouse.evidence')::uuid);raise exception 'Previously submitted evidence withdrawn';exception when unique_violation then null;end;end $$;
select set_config('openhouse.offer_version',(select version::text from public.contractor_work_offers where id='22334400-0000-4000-8000-000000000013'),true);
select set_config('openhouse.report',public.manage_completion_report(gen_random_uuid(),'submit','22334400-0000-4000-8000-000000000013',null,current_setting('openhouse.offer_version')::integer,0,'Replaced leaking valve and resealed the plumbing connection.','Final pressure remained stable at sixty PSI for thirty minutes.','No outstanding defects reported.',null,'Resubmitted completed work report',null)->>'id',true);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
select public.manage_completion_report('22334400-0000-4000-8000-000000000031','approve',null,current_setting('openhouse.report')::uuid,null,1,null,null,null,'Inspected work and accepted documented test results.','Independent completion approval',true);
select public.manage_completion_report('22334400-0000-4000-8000-000000000031','approve',null,current_setting('openhouse.report')::uuid,null,1,null,null,null,'Inspected work and accepted documented test results.','Independent completion approval',true);
do $$ begin
 if not exists(select 1 from public.work_orders where id='22334400-0000-4000-8000-000000000012' and status='completed' and completed_at is not null) or not exists(select 1 from public.contractor_work_offers where id='22334400-0000-4000-8000-000000000013' and state='completed') or not exists(select 1 from public.contractor_visits where id='22334400-0000-4000-8000-000000000014' and state='completed') or(select count(*) from public.contractor_completion_changes)<>4 then raise exception 'Completion transition/audit/retry failed';end if;
 begin update public.contractor_completion_reports set summary='Rewritten evidence after approval.';raise exception 'Direct report mutation';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000004',true);
do $$ begin if exists(select 1 from public.contractor_completion_reports) or exists(select 1 from public.contractor_completion_changes) or exists(select 1 from public.contractor_evidence) or exists(select 1 from storage.objects where bucket_id='contractor-evidence') then raise exception 'Foreign completion evidence visible';end if; if exists(select 1 from public.contractor_presence) or exists(select 1 from public.contractor_presence_changes) then raise exception 'Foreign presence visible';end if;end $$;
reset role;
do $$ begin begin update public.contractor_completion_reports set summary='Rewritten evidence after approval.' where id=current_setting('openhouse.report')::uuid;raise exception 'Trusted evidence rewrite';exception when unique_violation then null;end;end $$;
insert into public.staff_accounts(user_id,organization_id,role) values('22334400-0000-4000-8000-000000000002','22334400-0000-4000-8000-000000000007','manager');
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin begin perform public.manage_completion_report(gen_random_uuid(),'approve',null,current_setting('openhouse.report')::uuid,null,1,null,null,null,'Work accepted after inspection.','Dual role self approval',true);raise exception 'Dual role self approved';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000006',true);
do $$ begin if exists(select 1 from public.contractor_evidence) or exists(select 1 from public.contractor_report_evidence) or exists(select 1 from public.contractor_completion_reports) or exists(select 1 from public.contractor_completion_changes) then raise exception 'Security read completion details';end if;end $$;
do $$ begin begin perform public.claim_expired_contractor_evidence();raise exception 'Client claimed cleanup';exception when insufficient_privilege then null;end;end $$;
reset role;
insert into public.contractor_evidence(id,offer_id,organization_id,user_id,request_id,file_name,mime_type,declared_size,object_path,state,expires_at,purged_at) select ('22334400-0000-4000-8000-0000000000'||n)::uuid,'22334400-0000-4000-8000-000000000013','22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000002',gen_random_uuid(),'Fixture.pdf','application/pdf',10,'cleanup/'||n||'.pdf',state,expiry,purged from (values ('50','reserved',now()-interval '3 hours',null::timestamptz),('51','withdrawn',now()-interval '3 hours',null::timestamptz),('52','reserved',now()-interval '1 hour',null::timestamptz),('53','uploaded',now()-interval '3 hours',null::timestamptz),('54','expired',now()-interval '3 hours',now())) fixture(n,state,expiry,purged);
set local role service_role;
do $$ declare claimed integer;begin
 select count(*) into claimed from public.claim_expired_contractor_evidence();if claimed<>2 then raise exception 'Cleanup timing/state exclusions failed: %',claimed;end if;
 if not exists(select 1 from public.contractor_evidence_events where evidence_id='22334400-0000-4000-8000-000000000050' and actor_user_id is null and event_name='reservation_expired') then raise exception 'System expiry audit missing';end if;
 select count(*) into claimed from public.claim_expired_contractor_evidence();if claimed<>2 or(select count(*) from public.contractor_evidence_events where evidence_id='22334400-0000-4000-8000-000000000050')<>1 then raise exception 'Cleanup retry failed';end if;
 update public.contractor_evidence set purged_at=now() where id='22334400-0000-4000-8000-000000000050';
 select count(*) into claimed from public.claim_expired_contractor_evidence();if claimed<>1 then raise exception 'Purged evidence reclaimed';end if;
end $$;
reset role;
rollback;
