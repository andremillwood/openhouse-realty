begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('55667788-0000-4000-8000-000000000001','applicant@example.invalid',now()),
 ('55667788-0000-4000-8000-000000000002','other@example.invalid',now()),
 ('55667788-0000-4000-8000-000000000003','reviewer@example.invalid',now()),
 ('55667788-0000-4000-8000-000000000004','foreign@example.invalid',now()),
 ('55667788-0000-4000-8000-000000000005','unverified@example.invalid',null);
insert into public.organizations(id,name) values ('55667788-0000-4000-8000-000000000006','Application fixtures'),('55667788-0000-4000-8000-000000000007','Foreign application fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
 ('55667788-0000-4000-8000-000000000003','55667788-0000-4000-8000-000000000006','manager'),
 ('55667788-0000-4000-8000-000000000004','55667788-0000-4000-8000-000000000007','admin'),
 ('55667788-0000-4000-8000-000000000005','55667788-0000-4000-8000-000000000006','realtor'),
 ('55667788-0000-4000-8000-000000000001','55667788-0000-4000-8000-000000000006','realtor');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values
 ('55667788-0000-4000-8000-000000000008','55667788-0000-4000-8000-000000000006','Rental fixture','Kingston','rent','house','published',100000,'Approved rental fixture description.','https://example.invalid/approved.jpg'),
 ('55667788-0000-4000-8000-000000000009','55667788-0000-4000-8000-000000000006','Sale fixture','Kingston','sale','house','published',10000000,'Approved sale fixture description.','https://example.invalid/approved.jpg'),
 ('55667788-0000-4000-8000-000000000010','55667788-0000-4000-8000-000000000006','Draft rental fixture','Kingston','rent','house','draft',100000,'','');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url)
select ('55667788-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'55667788-0000-4000-8000-000000000006','Additional rental '||i,'Kingston','rent','house','published',100000,'Approved additional rental description.','https://example.invalid/approved.jpg' from generate_series(51,53) i;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
set local role authenticated;
select set_config('openhouse.att_event',public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Attendance fixture',now()+interval '2 days',now()+interval '2 days 1 hour',12,null,true)->>'event_id',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select set_config('openhouse.att_rsvp',public.reserve_open_house(current_setting('openhouse.att_event')::uuid,gen_random_uuid(),0,2,'reserve',true)->>'id',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
do $$ begin begin perform public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,gen_random_uuid(),1,0,'attended',1,'Confirmed fixture check-in');raise exception 'Early attendance accepted';exception when invalid_parameter_value then null;end;end $$;
reset role;
update public.open_house_events set starts_at=now()-interval '10 minutes',ends_at=now()+interval '50 minutes' where id=current_setting('openhouse.att_event')::uuid;
set local role authenticated;
select public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,'55667788-0000-4000-8000-000000000090',1,0,'attended',1,'Confirmed fixture check-in');
select public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,'55667788-0000-4000-8000-000000000090',1,0,'attended',1,'Confirmed fixture check-in');
do $$ begin
 if (select count(*) from public.open_house_attendance_changes)<>1 then raise exception 'Attendance retry duplicated audit';end if;
 begin perform public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,'55667788-0000-4000-8000-000000000090',1,0,'attended',2,'Changed fixture retry');raise exception 'Changed attendance retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,gen_random_uuid(),1,0,'attended',1,'Stale fixture check-in');raise exception 'Stale attendance accepted';exception when serialization_failure then null;end;
 begin perform public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,gen_random_uuid(),1,1,'attended',3,'Invalid fixture count');raise exception 'Attendance above reserved party';exception when invalid_parameter_value then null;end;
 begin perform public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,gen_random_uuid(),1,1,'no_show',0,'Premature absence record');raise exception 'Early no-show accepted';exception when invalid_parameter_value then null;end;
 begin update public.open_house_rsvps set attendance_state='no_show',attended_count=0;raise exception 'Staff bypassed attendance audit';exception when insufficient_privilege then null;end;
 if (public.open_house_staff_roster(current_setting('openhouse.att_event')::uuid,'going',1)->'rows'->0->>'attended_count')::int<>1 then raise exception 'Roster attendance missing';end if;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
do $$ begin
 if not exists(select 1 from public.open_house_rsvps where attendance_state='attended' and attended_count=1) then raise exception 'Own attendance hidden';end if;
 if exists(select 1 from public.open_house_attendance_changes) then raise exception 'Internal attendance audit disclosed to prospect';end if;
 begin perform public.reserve_open_house(current_setting('openhouse.att_event')::uuid,gen_random_uuid(),1,null,'cancel',null);raise exception 'Recorded attendance cancelled by prospect';exception when unique_violation then null;end;
 begin perform public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,gen_random_uuid(),1,1,'unrecorded',0,'Prospect forged attendance');raise exception 'Prospect changed attendance';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.open_house_attendance_changes) then raise exception 'Foreign attendance audit disclosure';end if;
 begin perform public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,gen_random_uuid(),1,1,'unrecorded',0,'Foreign forged attendance');raise exception 'Foreign changed attendance';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000005',true);
do $$ begin begin perform public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,gen_random_uuid(),1,1,'unrecorded',0,'Unverified forged attendance');raise exception 'Unverified changed attendance';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,gen_random_uuid(),1,1,'unrecorded',0,'Cleared incorrect fixture count');
reset role;
update public.open_house_events set starts_at=now()-interval '1 hour',ends_at=now()-interval '1 minute' where id=current_setting('openhouse.att_event')::uuid;
set local role authenticated;
select public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,gen_random_uuid(),1,2,'no_show',0,'Confirmed party did not attend');
select public.record_open_house_attendance(current_setting('openhouse.att_rsvp')::uuid,gen_random_uuid(),1,3,'unrecorded',0,'Cleared incorrect absence fixture');
do $$ begin if (select count(*) from public.open_house_attendance_changes)<>4 then raise exception 'Attendance correction audit missing';end if;end $$;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.reserve_open_house(current_setting('openhouse.att_event')::uuid,gen_random_uuid(),1,null,'cancel',null);
reset role;
rollback;
