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

insert into public.properties(id,organization_id,name) values('22334400-0000-4000-8000-000000000010','22334400-0000-4000-8000-000000000007','Offer fixture');
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.contractor',public.author_contractor_account(gen_random_uuid(),null,0,'contractor-target@example.invalid','Approved Contractor',array['Plumbing'],true,'Approved registration',true)->>'id',true);
select set_config('openhouse.job',public.manage_work_order(gen_random_uuid(),'create',null,0,'22334400-0000-4000-8000-000000000010',null,'Private issue','Internal details are not shared with contractors.','standard','Internal management reason')->>'id',true);
select public.manage_work_order(gen_random_uuid(),'triage',current_setting('openhouse.job')::uuid,1,null,null,null,null,'standard','Ready for approved scope');
select set_config('openhouse.offer',public.manage_contractor_work_offer('22334400-0000-4000-8000-000000000011','offer',null,current_setting('openhouse.job')::uuid,current_setting('openhouse.contractor')::uuid,0,2,'Plumbing assessment','Assess the approved kitchen plumbing issue.','Plumbing','Approved scope reviewed',true)->>'id',true);
do $$ begin
 if public.manage_contractor_work_offer('22334400-0000-4000-8000-000000000011','offer',null,current_setting('openhouse.job')::uuid,current_setting('openhouse.contractor')::uuid,0,2,'Plumbing assessment','Assess the approved kitchen plumbing issue.','Plumbing','Approved scope reviewed',true)->>'id'<>current_setting('openhouse.offer') then raise exception 'Offer retry failed';end if;
 begin perform public.manage_contractor_work_offer(gen_random_uuid(),'offer',null,current_setting('openhouse.job')::uuid,current_setting('openhouse.contractor')::uuid,0,2,'Plumbing assessment','Assess the approved kitchen plumbing issue.','Plumbing','Approved scope reviewed',true);raise exception 'Duplicate active offer';exception when unique_violation then null;end;
end $$;
reset role;
do $$ begin if (select count(*) from private.maintenance_notification_events where kind='offer_created')<>1 or not exists(select 1 from private.maintenance_notification_events where offer_id=current_setting('openhouse.offer')::uuid and kind='offer_created' and private.maintenance_notice_current(id)) then raise exception 'Created offer notice capture/retry/eligibility';end if; end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000006',true);
do $$ begin
 if exists(select 1 from public.contractor_work_offers) then raise exception 'Prospect saw offer';end if;
 begin perform public.manage_contractor_work_offer(gen_random_uuid(),'accept',current_setting('openhouse.offer')::uuid,null,null,1,null,null,null,null,'Accept approved work',null);raise exception 'Prospect accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
do $$ begin
 if (select count(*) from public.contractor_work_offers)<>1 then raise exception 'Own offer unavailable';end if;
 if exists(select 1 from public.work_orders) or exists(select 1 from public.contractor_work_offer_changes) then raise exception 'Internal management data exposed';end if;
end $$;
select public.manage_contractor_work_offer('22334400-0000-4000-8000-000000000012','accept',current_setting('openhouse.offer')::uuid,null,null,1,null,null,null,null,'Accept approved work',null);
select public.manage_contractor_work_offer('22334400-0000-4000-8000-000000000012','accept',current_setting('openhouse.offer')::uuid,null,null,1,null,null,null,null,'Accept approved work',null);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
do $$ begin
 if not exists(select 1 from public.work_orders where id=current_setting('openhouse.job')::uuid and status='assigned' and revision=3 and assigned_vendor_name='Approved Contractor') then raise exception 'Assignment failed';end if;
 if (select count(*) from public.contractor_work_offer_changes)<>2 then raise exception 'Retry duplicated audit';end if;
 begin perform public.author_contractor_account(gen_random_uuid(),current_setting('openhouse.contractor')::uuid,1,null,'Approved Contractor',array['Plumbing'],false,'Deactivate accepted contractor',true);raise exception 'Accepted contractor deactivated';exception when unique_violation then null;end;
end $$;
reset role;
do $$ begin if exists(select 1 from private.maintenance_notification_events where offer_id=current_setting('openhouse.offer')::uuid and private.maintenance_notice_current(id)) then raise exception 'Accepted offer retained review notice';end if; end $$;
set local role authenticated;
select public.manage_contractor_work_offer(gen_random_uuid(),'withdraw',current_setting('openhouse.offer')::uuid,null,null,2,null,null,null,null,'Withdraw before scheduling',null);
do $$ begin if not exists(select 1 from public.work_orders where id=current_setting('openhouse.job')::uuid and status='triaged' and revision=4 and assigned_vendor_name is null) then raise exception 'Unassignment failed';end if;end $$;
reset role;
do $$ begin if not exists(select 1 from private.maintenance_notification_events where offer_id=current_setting('openhouse.offer')::uuid and kind='offer_closed' and private.maintenance_notice_current(id)) then raise exception 'Withdrawn offer notice absent';end if; end $$;
set local role authenticated;
select set_config('openhouse.offer2',public.manage_contractor_work_offer(gen_random_uuid(),'offer',null,current_setting('openhouse.job')::uuid,current_setting('openhouse.contractor')::uuid,0,4,'Plumbing assessment','Assess the approved kitchen plumbing issue.','Plumbing','Approved scope reviewed',true)->>'id',true);
reset role;
do $$ begin if exists(select 1 from private.maintenance_notification_events where offer_id=current_setting('openhouse.offer')::uuid and private.maintenance_notice_current(id)) then raise exception 'Replacement retained old closure notice';end if; if not exists(select 1 from private.maintenance_notification_events where offer_id=current_setting('openhouse.offer2')::uuid and kind='offer_created' and private.maintenance_notice_current(id)) then raise exception 'Replacement offer review notice absent';end if; end $$;
set local role authenticated;
select public.manage_work_order(gen_random_uuid(),'triage',current_setting('openhouse.job')::uuid,4,null,null,null,null,'high','Changed assessment priority');
do $$ begin if not exists(select 1 from public.contractor_work_offers where id=current_setting('openhouse.offer2')::uuid and state='withdrawn' and version=2) then raise exception 'Changed triage retained offer';end if;end $$;

select set_config('openhouse.offer3',public.manage_contractor_work_offer(gen_random_uuid(),'offer',null,current_setting('openhouse.job')::uuid,current_setting('openhouse.contractor')::uuid,0,5,'Plumbing assessment','Assess the approved kitchen plumbing issue.','Plumbing','Approved scope reviewed',true)->>'id',true);
select public.author_contractor_account(gen_random_uuid(),current_setting('openhouse.contractor')::uuid,1,null,'Approved Contractor',array['Plumbing'],true,'Updated approved registration',true);
do $$ begin if not exists(select 1 from public.contractor_work_offers where id=current_setting('openhouse.offer3')::uuid and state='withdrawn') then raise exception 'Registry update retained pending offer';end if;end $$;
select set_config('openhouse.offer4',public.manage_contractor_work_offer(gen_random_uuid(),'offer',null,current_setting('openhouse.job')::uuid,current_setting('openhouse.contractor')::uuid,0,5,'Plumbing assessment','Assess the approved kitchen plumbing issue.','Plumbing','Approved scope reviewed',true)->>'id',true);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
select public.manage_contractor_work_offer(gen_random_uuid(),'decline',current_setting('openhouse.offer4')::uuid,null,null,1,null,null,null,null,'Unavailable for this work',null);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
select set_config('openhouse.offer5',public.manage_contractor_work_offer(gen_random_uuid(),'offer',null,current_setting('openhouse.job')::uuid,current_setting('openhouse.contractor')::uuid,0,5,'Plumbing assessment','Assess the approved kitchen plumbing issue.','Plumbing','Approved scope reviewed',true)->>'id',true);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
select public.manage_contractor_work_offer(gen_random_uuid(),'accept',current_setting('openhouse.offer5')::uuid,null,null,1,null,null,null,null,'Accept approved work',null);
do $$ begin begin perform public.manage_contractor_work_offer(gen_random_uuid(),'release',current_setting('openhouse.offer5')::uuid,null,null,1,null,null,null,null,'Release accepted work',null);raise exception 'Stale release accepted';exception when serialization_failure then null;end;end $$;
select public.manage_contractor_work_offer(gen_random_uuid(),'release',current_setting('openhouse.offer5')::uuid,null,null,2,null,null,null,null,'Release accepted work',null);
reset role;
insert into public.contractor_work_offers(organization_id,work_order_id,contractor_id,company_name_snapshot,job_title,scope_summary,trade,work_version,state,expires_at) values('22334400-0000-4000-8000-000000000007',current_setting('openhouse.job')::uuid,current_setting('openhouse.contractor')::uuid,'Approved Contractor','Expired assessment','Assess the approved kitchen plumbing issue.','Plumbing',7,'offered',now()-interval '1 day');
select set_config('openhouse.expired',(select id::text from public.contractor_work_offers where work_order_id=current_setting('openhouse.job')::uuid and state='offered'),true);
set local role authenticated;
do $$ begin if public.manage_contractor_work_offer(gen_random_uuid(),'accept',current_setting('openhouse.expired')::uuid,null,null,1,null,null,null,null,'Accept expired offer',null)->>'state'<>'expired' then raise exception 'Expired offer accepted';end if;end $$;
reset role;
do $$ begin if not exists(select 1 from private.maintenance_notification_events where offer_id=current_setting('openhouse.expired')::uuid and kind='offer_closed' and private.maintenance_notice_current(id)) then raise exception 'Expired closure notice absent';end if; if exists(select 1 from private.maintenance_notification_events where kind='offer_created' and private.maintenance_notice_current(id)) then raise exception 'Retired offer review eligible';end if; end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000004',true);
do $$ begin if exists(select 1 from public.contractor_work_offers) or exists(select 1 from public.contractor_work_offer_changes) then raise exception 'Foreign manager saw offers';end if;end $$;
reset role;
rollback;
