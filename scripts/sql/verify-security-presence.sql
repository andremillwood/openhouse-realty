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
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
do $$ begin if not exists(select 1 from public.work_orders where id='22334400-0000-4000-8000-000000000012' and status='on_site' and revision=4) then raise exception 'On-site transition failed';end if;end $$;
select public.manage_entry_permit(gen_random_uuid(),'revoke',current_setting('openhouse.permit')::uuid,null,1,null,null,null,null,'Revoke access while on site',null);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000006',true);
select public.record_contractor_presence('22334400-0000-4000-8000-000000000021','check_out',null,current_setting('openhouse.presence')::uuid,1,null,'Confirmed departure after revocation');
select public.record_contractor_presence('22334400-0000-4000-8000-000000000021','check_out',null,current_setting('openhouse.presence')::uuid,1,null,'Confirmed departure after revocation');
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
do $$ begin if not exists(select 1 from public.work_orders where id='22334400-0000-4000-8000-000000000012' and status='in_progress' and revision=5) or not exists(select 1 from public.contractor_presence where id=current_setting('openhouse.presence')::uuid and state='exited' and version=2 and checked_out_at is not null) or(select count(*) from public.contractor_presence_changes)<>2 then raise exception 'Departure transition/retry failed';end if;end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000004',true);
do $$ begin if exists(select 1 from public.contractor_presence) or exists(select 1 from public.contractor_presence_changes) then raise exception 'Foreign presence visible';end if;end $$;
reset role;
rollback;
