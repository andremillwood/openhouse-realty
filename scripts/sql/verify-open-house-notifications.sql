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
select set_config('openhouse.notice_event',public.author_open_house_event('create',gen_random_uuid(),null,0,'55667788-0000-4000-8000-000000000008','Notice fixture event',now()+interval '2 days',now()+interval '2 days 1 hour',12,null,true)->>'event_id',true);
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.reserve_open_house(current_setting('openhouse.notice_event')::uuid,'55667788-0000-4000-8000-000000000095',0,2,'reserve',true);
select public.reserve_open_house(current_setting('openhouse.notice_event')::uuid,'55667788-0000-4000-8000-000000000095',0,2,'reserve',true);
do $$ begin begin perform 1 from private.open_house_notices;raise exception 'Prospect accessed private notices';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$ begin
 if (select count(*) from private.open_house_notices)<>2 or (select count(*) from private.notification_outbox)<>2 then raise exception 'Reservation notice/retry duplicated or missing';end if;
 if not exists(select 1 from private.notification_outbox o join private.open_house_notices n on n.id=o.open_house_notice_id join public.open_house_rsvps r on r.id=n.rsvp_id join public.open_house_events e on e.id=r.event_id where n.kind='reminder' and o.available_at=e.starts_at-interval '24 hours') then raise exception 'Reminder scheduling incorrect';end if;
 if exists(select 1 from private.notification_outbox where organization_id<>'55667788-0000-4000-8000-000000000006' or recipient<>'other@example.invalid') then raise exception 'Derived notification identity incorrect';end if;
end $$;
set local role service_role;
do $$ begin if exists(select 1 from public.claim_enquiry_notifications('sender@example.invalid','recipient@example.invalid')) then raise exception 'Legacy worker claimed link-bearing event notice';end if;end $$;
select set_config('openhouse.notice_outbox',(select outbox_id::text from public.claim_transactional_notifications('Open House <notifications@example.invalid>','business@example.invalid','https://first.example.invalid')),true);
select set_config('openhouse.notice_lease',(select lease_token::text from private.notification_outbox where id=current_setting('openhouse.notice_outbox')::uuid),true);
do $$ begin
 if not public.notification_attempt_current(current_setting('openhouse.notice_outbox')::uuid,current_setting('openhouse.notice_lease')::uuid) then raise exception 'Current notice preflight rejected';end if;
 if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.notice_outbox')::uuid and text_snapshot like '%https://first.example.invalid/account/open-houses') then raise exception 'Canonical private account link missing';end if;
end $$;
reset role;
update private.notification_outbox set lease_expires_at=now()-interval '1 minute' where id=current_setting('openhouse.notice_outbox')::uuid;
set local role service_role;
select * from public.claim_transactional_notifications('Changed <changed@example.invalid>','changed@example.invalid','https://changed.example.invalid');
do $$ begin if not exists(select 1 from private.notification_outbox where id=current_setting('openhouse.notice_outbox')::uuid and sender='Open House <notifications@example.invalid>' and recipient='other@example.invalid' and text_snapshot like '%https://first.example.invalid/account/open-houses' and text_snapshot not like '%changed.example.invalid%') then raise exception 'Retry changed frozen sender/recipient/link';end if;end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.reserve_open_house(current_setting('openhouse.notice_event')::uuid,gen_random_uuid(),1,1,'reserve',true);
reset role;
set local role service_role;
do $$ begin if public.notification_attempt_current(current_setting('openhouse.notice_outbox')::uuid,(select lease_token from private.notification_outbox where id=current_setting('openhouse.notice_outbox')::uuid)) then raise exception 'Changed RSVP notice still sendable';end if;end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000003',true);
select public.author_open_house_arrival(current_setting('openhouse.notice_event')::uuid,gen_random_uuid(),0,'save','PRIVATE POINT MUST NOT BE EMAILED','PRIVATE DIRECTIONS MUST NOT BE EMAILED',18.02,-76.77,'Approved private fixture instructions',true);
select public.author_open_house_arrival(current_setting('openhouse.notice_event')::uuid,gen_random_uuid(),1,'withdraw',null,null,null,null,'Private directions temporarily withdrawn',null);
reset role;
do $$ begin
 if exists(select 1 from private.notification_outbox where text_snapshot like '%PRIVATE POINT%' or text_snapshot like '%PRIVATE DIRECTIONS%' or text_snapshot like '%-76.77%') then raise exception 'Private location leaked into email snapshot';end if;
 if (select count(*) from private.notification_outbox o join private.open_house_notices n on n.id=o.open_house_notice_id where n.kind='arrival_updated' and o.state='pending')<>1 then raise exception 'Arrival changes did not supersede obsolete notice';end if;
end $$;
set local role authenticated;
reset role;
update public.listings set status='paused' where id='55667788-0000-4000-8000-000000000008';
do $$ begin if (select count(*) from private.notification_outbox o join private.open_house_notices n on n.id=o.open_house_notice_id where o.state='pending' and n.kind='unavailable')<>1 then raise exception 'Unavailable event notice missing';end if;end $$;
update public.listings set status='published' where id='55667788-0000-4000-8000-000000000008';
do $$ begin if exists(select 1 from private.notification_outbox o join private.open_house_notices n on n.id=o.open_house_notice_id where o.state in('pending','processing') and n.kind='unavailable') then raise exception 'Republication left stale unavailable notice';end if;end $$;
update public.listings set status='paused' where id='55667788-0000-4000-8000-000000000008';
do $$ begin if (select count(*) from private.notification_outbox o join private.open_house_notices n on n.id=o.open_house_notice_id where o.state='pending' and n.kind='unavailable')<>1 then raise exception 'Publication cycles duplicate unavailable notices';end if;end $$;
update public.listings set status='published' where id='55667788-0000-4000-8000-000000000008';
set local role authenticated;
select public.author_open_house_event('cancel',gen_random_uuid(),current_setting('openhouse.notice_event')::uuid,1,null,null,null,null,null,'Fixture event cancelled',null);
do $$ declare result jsonb;begin
 result:=public.staff_notification_delivery_monitor('all','open_house','all',1);
 if (result->>'total')::int<7 or exists(select 1 from jsonb_array_elements(result->'rows') row where row->>'family'<>'open_house' or row ? 'recipient' or row ? 'text_snapshot') then raise exception 'Open house delivery monitor wrong or private payload exposed';end if;
end $$;
reset role;
do $$ begin
 if (select count(*) from private.notification_outbox o join private.open_house_notices n on n.id=o.open_house_notice_id where o.state='pending' and n.kind='event_cancelled')<>1 or exists(select 1 from private.notification_outbox o join private.open_house_notices n on n.id=o.open_house_notice_id where o.state in('pending','processing') and n.kind<>'event_cancelled') then raise exception 'Cancelled event notice currency incorrect';end if;
end $$;
set local role service_role;
select set_config('openhouse.cancel_outbox',(select outbox_id::text from public.claim_transactional_notifications('Open House <notifications@example.invalid>','business@example.invalid','https://first.example.invalid')),true);
select set_config('openhouse.cancel_lease',(select lease_token::text from private.notification_outbox where id=current_setting('openhouse.cancel_outbox')::uuid),true);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','55667788-0000-4000-8000-000000000002',true);
select public.reserve_open_house(current_setting('openhouse.notice_event')::uuid,gen_random_uuid(),2,null,'cancel',null);
reset role;
set local role service_role;
do $$ begin if public.notification_attempt_current(current_setting('openhouse.cancel_outbox')::uuid,current_setting('openhouse.cancel_lease')::uuid) then raise exception 'Outdated event cancellation notice still sendable';end if;end $$;
reset role;
update private.open_house_notices set expires_at=now()-interval '1 minute' where kind='rsvp_cancelled';
set local role service_role;
do $$ begin if exists(select 1 from public.claim_transactional_notifications('Open House <notifications@example.invalid>','business@example.invalid','https://first.example.invalid')) then raise exception 'Expired RSVP cancellation sent';end if;end $$;
reset role;
set local role anon;
do $$ begin begin perform 1 from public.claim_transactional_notifications('sender@example.invalid','recipient@example.invalid','https://first.example.invalid');raise exception 'Anonymous claimed worker notices';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
