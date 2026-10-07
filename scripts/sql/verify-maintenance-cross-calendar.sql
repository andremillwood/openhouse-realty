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
select public.manage_contractor_work_offer(gen_random_uuid(),'accept',current_setting('openhouse.offer')::uuid,null,null,1,null,null,null,null,'Accept approved work',null);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
select set_config('openhouse.visit',public.manage_contractor_visit('22334400-0000-4000-8000-000000000020','propose',null,current_setting('openhouse.offer')::uuid,0,2,now()+interval '2 days',now()+interval '2 days 1 hour','Approved appointment note','Proposed after management review',true)->>'id',true);
select public.manage_contractor_visit('22334400-0000-4000-8000-000000000020','propose',null,current_setting('openhouse.offer')::uuid,0,2,now()+interval '2 days',now()+interval '2 days 1 hour','Approved appointment note','Proposed after management review',true);
reset role;
insert into public.properties(id,organization_id,name) values('22334400-0000-4000-8000-000000000030','22334400-0000-4000-8000-000000000007','Another managed property');
insert into public.work_orders(id,organization_id,property_id,title,description,status,priority,revision) values('22334400-0000-4000-8000-000000000031','22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000030','Second job','Approved work at another managed property.','assigned','standard',3);
insert into public.contractor_work_offers(id,organization_id,work_order_id,contractor_id,company_name_snapshot,job_title,scope_summary,trade,work_version,state,expires_at) values('22334400-0000-4000-8000-000000000032','22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000031',current_setting('openhouse.contractor')::uuid,'Approved Contractor','Another job','Approved scope at another managed property.','Plumbing',3,'accepted',now()+interval '7 days');
set local role authenticated;
do $$ begin
 begin perform public.manage_contractor_visit(gen_random_uuid(),'propose',null,'22334400-0000-4000-8000-000000000032',0,1,now()+interval '2 days 30 minutes',now()+interval '2 days 90 minutes','Overlapping job appointment','Approved second appointment',true);raise exception 'Contractor overlap accepted';exception when unique_violation then null;end;
 begin perform public.manage_contractor_visit(gen_random_uuid(),'propose',null,'22334400-0000-4000-8000-000000000032',0,1,now()-interval '1 hour',now()+interval '1 hour','Past job appointment','Approved second appointment',true);raise exception 'Past visit accepted';exception when invalid_parameter_value then null;end;
end $$;
select public.manage_contractor_visit(gen_random_uuid(),'propose',null,'22334400-0000-4000-8000-000000000032',0,1,now()+interval '2 days 1 hour',now()+interval '2 days 2 hours','Adjacent job appointment','Approved adjacent appointment',true);
do $$ begin
 if(select count(*) from public.contractor_visits)<>2 or(select count(*) from public.contractor_visit_changes)<>2 then raise exception 'Proposal retry duplicated';end if;
 begin perform public.manage_contractor_work_offer(gen_random_uuid(),'withdraw',current_setting('openhouse.offer')::uuid,null,null,2,null,null,null,null,'Withdraw during active visit',null);raise exception 'Active visit withdrawal allowed';exception when unique_violation then null;end;
 begin perform public.manage_contractor_visit(gen_random_uuid(),'propose',null,current_setting('openhouse.offer')::uuid,0,2,now()+interval '2 days',now()+interval '2 days 1 hour','Approved appointment note','Duplicate visit proposal',true);raise exception 'Duplicate visit allowed';exception when unique_violation then null;end;
 begin perform public.manage_contractor_visit(gen_random_uuid(),'confirm',current_setting('openhouse.visit')::uuid,null,1,null,null,null,null,'Manager confirmed contractor visit',null);raise exception 'Manager impersonated contractor';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
do $$ begin if(select count(*) from public.contractor_visits)<>2 or exists(select 1 from public.contractor_visit_changes) then raise exception 'Contractor visit privacy failed';end if;end $$;
select public.manage_contractor_visit('22334400-0000-4000-8000-000000000021','confirm',current_setting('openhouse.visit')::uuid,null,1,null,null,null,null,'Confirmed appointment window',null);
select public.manage_contractor_visit('22334400-0000-4000-8000-000000000021','confirm',current_setting('openhouse.visit')::uuid,null,1,null,null,null,null,'Confirmed appointment window',null);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
do $$ begin
 if not exists(select 1 from public.work_orders where id=current_setting('openhouse.job')::uuid and status='scheduled' and revision=4 and scheduled_start=now()+interval '2 days') then raise exception 'Schedule transition failed';end if;
 if(select count(*) from public.contractor_visit_changes)<>3 then raise exception 'Confirm retry duplicated';end if;
 begin perform public.manage_contractor_visit(gen_random_uuid(),'cancel',current_setting('openhouse.visit')::uuid,null,1,null,null,null,null,'Stale cancellation attempt',null);raise exception 'Stale cancellation accepted';exception when serialization_failure then null;end;
end $$;
select public.manage_contractor_visit(gen_random_uuid(),'cancel',current_setting('openhouse.visit')::uuid,null,2,null,null,null,null,'Cancelled before entry',null);
do $$ begin if not exists(select 1 from public.work_orders where id=current_setting('openhouse.job')::uuid and status='assigned' and revision=5 and scheduled_start is null and scheduled_end is null) then raise exception 'Cancellation did not restore assignment';end if;end $$;
select set_config('openhouse.visit2',public.manage_contractor_visit(gen_random_uuid(),'propose',null,current_setting('openhouse.offer')::uuid,0,4,now()+interval '3 days',now()+interval '3 days 1 hour','Approved replacement window','Approved replacement visit',true)->>'id',true);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000002',true);
select public.manage_contractor_visit(gen_random_uuid(),'decline',current_setting('openhouse.visit2')::uuid,null,1,null,null,null,null,'Unavailable for replacement',null);
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000004',true);
do $$ begin if exists(select 1 from public.contractor_visits) or exists(select 1 from public.contractor_visit_changes) then raise exception 'Foreign visit read allowed';end if;end $$;
reset role;
do $$ begin begin update public.contractor_visits set starts_at=starts_at+interval '1 hour',ends_at=ends_at+interval '1 hour' where id=current_setting('openhouse.visit')::uuid;raise exception 'Trusted schedule identity changed';exception when unique_violation then null;end;end $$;

insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,property_id) values
('22334400-0000-4000-8000-000000000040','22334400-0000-4000-8000-000000000007','Mapped resource','Kingston','rent','house','draft',100000,'22334400-0000-4000-8000-000000000010'),
('22334400-0000-4000-8000-000000000041','22334400-0000-4000-8000-000000000007','Unmapped prospect listing','Kingston','rent','house','draft',100000,null);
insert into public.open_house_events(id,listing_id,title,starts_at,ends_at,capacity) values('22334400-0000-4000-8000-000000000042','22334400-0000-4000-8000-000000000041','Prospect fixture',now()+interval '3 days',now()+interval '3 days 1 hour',10);
insert into public.open_house_rsvps(event_id,organization_id,user_id,party_size,status) values('22334400-0000-4000-8000-000000000042','22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000002',1,'going');
insert into public.viewings(user_id,listing_id,requested_for,ends_at,status,hold_expires_at) values('22334400-0000-4000-8000-000000000002','22334400-0000-4000-8000-000000000041',now()+interval '4 days',now()+interval '4 days 1 hour','requested',now()+interval '10 minutes');
select set_config('request.jwt.claim.sub','22334400-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 begin perform public.manage_contractor_visit(gen_random_uuid(),'propose',null,current_setting('openhouse.offer')::uuid,0,4,now()+interval '3 days',now()+interval '3 days 1 hour','Approved visit note','Approved appointment proposal',true);raise exception 'Visit overlaps RSVP';exception when unique_violation then null;end;
 begin perform public.manage_contractor_visit(gen_random_uuid(),'propose',null,current_setting('openhouse.offer')::uuid,0,4,now()+interval '4 days',now()+interval '4 days 1 hour','Approved visit note','Approved appointment proposal',true);raise exception 'Visit overlaps viewing hold';exception when unique_violation then null;end;
end $$;
reset role;
update public.viewings set hold_expires_at=now()-interval '1 minute' where user_id='22334400-0000-4000-8000-000000000002' and requested_for=now()+interval '4 days';
set local role authenticated;
select set_config('openhouse.cross_visit',public.manage_contractor_visit(gen_random_uuid(),'propose',null,current_setting('openhouse.offer')::uuid,0,4,now()+interval '4 days',now()+interval '4 days 1 hour','Approved visit note','Approved appointment proposal',true)->>'id',true);
reset role;
do $$ begin
 begin insert into public.viewings(user_id,listing_id,requested_for,ends_at,status) values('22334400-0000-4000-8000-000000000002','22334400-0000-4000-8000-000000000041',now()+interval '4 days',now()+interval '4 days 1 hour','confirmed');raise exception 'Viewing overlaps maintenance';exception when unique_violation then null;end;
 begin insert into public.open_house_events(listing_id,title,starts_at,ends_at,capacity) values('22334400-0000-4000-8000-000000000040','Conflicting location',now()+interval '4 days',now()+interval '4 days 1 hour',10);raise exception 'Open house overlaps maintenance location';exception when unique_violation then null;end;
 begin insert into public.viewing_slots(organization_id,listing_id,request_id,starts_at,ends_at) values('22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000040',gen_random_uuid(),now()+interval '4 days',now()+interval '4 days 1 hour');raise exception 'Viewing slot overlaps maintenance location';exception when unique_violation then null;end;
end $$;

insert into public.open_house_events(id,listing_id,title,starts_at,ends_at,capacity) values('22334400-0000-4000-8000-000000000043','22334400-0000-4000-8000-000000000041','Later prospect fixture',now()+interval '4 days',now()+interval '4 days 1 hour',10);
do $$ begin begin insert into public.open_house_rsvps(event_id,organization_id,user_id,party_size,status) values('22334400-0000-4000-8000-000000000043','22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000002',1,'going');raise exception 'RSVP overlaps maintenance';exception when unique_violation then null;end;end $$;
set local role authenticated;
select public.manage_contractor_visit(gen_random_uuid(),'cancel',current_setting('openhouse.cross_visit')::uuid,null,1,null,null,null,null,'Cancel before resource checks',null);
reset role;
insert into public.viewing_slots(organization_id,listing_id,request_id,starts_at,ends_at) values('22334400-0000-4000-8000-000000000007','22334400-0000-4000-8000-000000000040',gen_random_uuid(),now()+interval '6 days',now()+interval '6 days 1 hour');
set local role authenticated;
do $$ begin begin perform public.manage_contractor_visit(gen_random_uuid(),'propose',null,current_setting('openhouse.offer')::uuid,0,4,now()+interval '6 days',now()+interval '6 days 1 hour','Approved visit note','Approved appointment proposal',true);raise exception 'Maintenance overlaps viewing resource';exception when unique_violation then null;end;end $$;
reset role;
rollback;
