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
select public.manage_completion_report(gen_random_uuid(),'request_changes',null,current_setting('openhouse.report')::uuid,null,1,null,null,null,'Please document the final pressure readings.','Requested test result detail',null);

select set_config('openhouse.return_offer_version',(select version::text from public.contractor_work_offers where id='22334400-0000-4000-8000-000000000013'),true);
select set_config('openhouse.return_work_version',(select revision::text from public.work_orders where id='22334400-0000-4000-8000-000000000012'),true);
do $$ begin
 begin perform public.request_contractor_return_visit(gen_random_uuid(),current_setting('openhouse.report')::uuid,2,current_setting('openhouse.return_offer_version')::integer,current_setting('openhouse.return_work_version')::integer,'Approved physical correction visit',false);raise exception 'Missing approval accepted';exception when invalid_parameter_value then null;end;
 begin perform public.request_contractor_return_visit(gen_random_uuid(),current_setting('openhouse.report')::uuid,1,current_setting('openhouse.return_offer_version')::integer,current_setting('openhouse.return_work_version')::integer,'Approved physical correction visit',true);raise exception 'Stale report accepted';exception when serialization_failure then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
do $$ begin begin perform public.request_contractor_return_visit(gen_random_uuid(),current_setting('openhouse.report')::uuid,2,current_setting('openhouse.return_offer_version')::integer,current_setting('openhouse.return_work_version')::integer,'Contractor requested own return',true);raise exception 'Contractor reset own work';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000004',true);
do $$ begin begin perform public.request_contractor_return_visit(gen_random_uuid(),current_setting('openhouse.report')::uuid,2,current_setting('openhouse.return_offer_version')::integer,current_setting('openhouse.return_work_version')::integer,'Foreign manager return',true);raise exception 'Foreign reset accepted';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
select public.request_contractor_return_visit('22334400-0000-4000-8000-000000000040',current_setting('openhouse.report')::uuid,2,current_setting('openhouse.return_offer_version')::integer,current_setting('openhouse.return_work_version')::integer,'Approved physical correction visit',true);
select public.request_contractor_return_visit('22334400-0000-4000-8000-000000000040',current_setting('openhouse.report')::uuid,2,current_setting('openhouse.return_offer_version')::integer,current_setting('openhouse.return_work_version')::integer,'Approved physical correction visit',true);
do $$ begin
 if not exists(select 1 from public.work_orders where id='22334400-0000-4000-8000-000000000012' and status='assigned' and completed_at is null and scheduled_start is null and scheduled_end is null and revision=current_setting('openhouse.return_work_version')::integer+1) then raise exception 'Return transition failed';end if;
 if not exists(select 1 from public.contractor_visits where id='22334400-0000-4000-8000-000000000014' and state='completed') or not exists(select 1 from public.contractor_presence where id=current_setting('openhouse.presence')::uuid and state='exited' and version=2) or not exists(select 1 from public.contractor_completion_reports where id=current_setting('openhouse.report')::uuid and state='changes_requested' and version=2) then raise exception 'Historical records changed';end if;
 if (select count(*) from public.work_order_changes where action='return_visit')<>1 or (select count(*) from public.contractor_visit_changes where action='return_visit')<>1 then raise exception 'Return retry duplicated';end if;
 begin perform public.request_contractor_return_visit('22334400-0000-4000-8000-000000000040',current_setting('openhouse.report')::uuid,2,current_setting('openhouse.return_offer_version')::integer,current_setting('openhouse.return_work_version')::integer,'Changed nonce payload',true);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('openhouse.return_visit',public.manage_contractor_visit(gen_random_uuid(),'propose',null,'22334400-0000-4000-8000-000000000013',0,(select version from public.contractor_work_offers where id='22334400-0000-4000-8000-000000000013'),now()+interval '1 day',now()+interval '1 day 2 hours','Correct leaking connection following shared review','Manager approved correction visit',true)->>'id',true);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
select public.manage_contractor_visit(gen_random_uuid(),'confirm',current_setting('openhouse.return_visit')::uuid,null,1,null,null,null,null,'Confirmed correction appointment',null);
do $$ begin
 begin perform public.manage_completion_report(gen_random_uuid(),'submit','22334400-0000-4000-8000-000000000013',null,(select version from public.contractor_work_offers where id='22334400-0000-4000-8000-000000000013'),0,'Corrected leaking valve and resealed the plumbing connection.','Pressure tested for thirty minutes.','No outstanding defects reported.',null,'Premature correction completion',null);raise exception 'Return completion before arrival allowed';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
do $$ begin if not exists(select 1 from public.work_orders where id='22334400-0000-4000-8000-000000000012' and status='scheduled' and completed_at is null) then raise exception 'New appointment scheduling failed';end if;end $$;
do $$ begin begin perform 1 from private.maintenance_notification_events;raise exception 'Authenticated read private events';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$ begin
 if (select count(*) from private.maintenance_notification_events where kind='return_visit')<>1 then raise exception 'Return event duplicated or absent';end if;
 if not exists(select 1 from private.maintenance_notification_events where kind='report_submitted') or not exists(select 1 from private.maintenance_notification_events where kind='changes_requested') or not exists(select 1 from private.maintenance_notification_events where kind='visit_proposed') or not exists(select 1 from private.maintenance_notification_events where kind='visit_confirmed') then raise exception 'Lifecycle event absent';end if;
 if exists(select 1 from private.maintenance_notification_events where organization_id<>'22334400-0000-4000-8000-000000000007' or offer_id<>'22334400-0000-4000-8000-000000000013' or work_order_id<>'22334400-0000-4000-8000-000000000012' or contractor_user_id<>'22334400-0000-4000-8000-000000000002') then raise exception 'Event binding incorrect';end if;
 if not exists(select 1 from private.maintenance_notification_events n join public.work_order_changes c on c.id=n.source_id where n.kind='return_visit' and n.work_version=c.version and n.source_version=c.version) then raise exception 'Snapshot revision incorrect';end if;
end $$;
set local role service_role;
do $$ begin if not exists(select 1 from private.maintenance_notification_events) then raise exception 'Service read missing';end if;begin update private.maintenance_notification_events set kind='work_completed';raise exception 'Service rewrote event';exception when insufficient_privilege then null;end;end $$;
select set_config('openhouse.notice_event',(select event_id::text from public.pending_maintenance_notifications() where kind='visit_confirmed'),true);
select set_config('openhouse.notice_outbox',public.queue_maintenance_notification(current_setting('openhouse.notice_event')::uuid,'Appointment confirmed','Review the confirmed appointment in your account. Sign in: ')::text,true);
select public.queue_maintenance_notification(current_setting('openhouse.notice_event')::uuid,'Changed retry subject','This retry must not rewrite the stored notification snapshot.');
do $$ begin
 if (select count(*) from private.notification_outbox where maintenance_event_id=current_setting('openhouse.notice_event')::uuid)<>1 then raise exception 'Notification duplicated';end if;
 if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.notice_outbox')::uuid and audience='contractor' and recipient='contractor-target@example.invalid' and organization_id='22334400-0000-4000-8000-000000000007' and action_path='/account/work-offers/22334400-0000-4000-8000-000000000013' and subject_snapshot='Appointment confirmed') then raise exception 'Snapshot binding or retry failed';end if;
 if exists(select 1 from public.pending_maintenance_notifications()) then raise exception 'Queued event still pending preparation';end if;
end $$;
select set_config('openhouse.notice_lease',(select lease_token::text from public.claim_transactional_notifications('Open House <notifications@example.invalid>','management@example.invalid','https://example.invalid') where outbox_id=current_setting('openhouse.notice_outbox')::uuid),true);
do $$ begin if not public.notification_attempt_current(current_setting('openhouse.notice_outbox')::uuid,current_setting('openhouse.notice_lease')::uuid) then raise exception 'Current attempt denied';end if;end $$;
reset role;
update auth.users set email='changed@example.invalid' where id='22334400-0000-4000-8000-000000000002';
set local role service_role;
do $$ begin if public.notification_attempt_current(current_setting('openhouse.notice_outbox')::uuid,current_setting('openhouse.notice_lease')::uuid) then raise exception 'Changed recipient still eligible';end if;end $$;
select public.claim_transactional_notifications('Open House <notifications@example.invalid>','management@example.invalid','https://example.invalid');
do $$ begin if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.notice_outbox')::uuid and state='superseded' and lease_token is null) then raise exception 'Changed recipient not superseded';end if;end $$;
reset role;
set local role authenticated;
do $$ begin begin perform public.pending_maintenance_notifications();raise exception 'Client listed notifications';exception when insufficient_privilege then null;end;begin perform public.queue_maintenance_notification(gen_random_uuid(),'Subject','Private client insertion attempt');raise exception 'Client queued notification';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
