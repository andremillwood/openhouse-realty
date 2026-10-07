begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('22334455-0000-4000-8000-000000000001','prospect-test@example.invalid',now()),
 ('22334455-0000-4000-8000-000000000002','other-test@example.invalid',now()),
 ('22334455-0000-4000-8000-000000000003','staff-test@example.invalid',now());
insert into public.organizations(id,name) values ('22334455-0000-4000-8000-000000000004','Enquiry test organization');
insert into public.staff_accounts(user_id,organization_id,role) values ('22334455-0000-4000-8000-000000000003','22334455-0000-4000-8000-000000000004','realtor');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values ('22334455-0000-4000-8000-000000000005','22334455-0000-4000-8000-000000000004','Enquiry fixture','Test area','rent','house','published',100,'An approved-length fixture description for permission tests.','https://example.invalid/fixture.jpg');
insert into auth.users(id,email,email_confirmed_at) values
 ('22334455-0000-4000-8000-000000000012','foreign-staff@example.invalid',now()),
 ('22334455-0000-4000-8000-000000000013','colleague@example.invalid',now()),
 ('22334455-0000-4000-8000-000000000014','finance@example.invalid',now()),
 ('22334455-0000-4000-8000-000000000015','unverified@example.invalid',null);
insert into public.organizations(id,name) values ('22334455-0000-4000-8000-000000000016','Foreign collaboration organization');
insert into public.staff_accounts(user_id,organization_id,role) values
 ('22334455-0000-4000-8000-000000000012','22334455-0000-4000-8000-000000000016','admin'),
 ('22334455-0000-4000-8000-000000000013','22334455-0000-4000-8000-000000000004','manager'),
 ('22334455-0000-4000-8000-000000000014','22334455-0000-4000-8000-000000000004','finance'),
 ('22334455-0000-4000-8000-000000000015','22334455-0000-4000-8000-000000000004','realtor');
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000001',true);
set local role authenticated;
select public.submit_enquiry('22334455-0000-4000-8000-000000000006','22334455-0000-4000-8000-000000000005',null,'Test prospect','','Please arrange a viewing for this property.',true);
select public.submit_enquiry('22334455-0000-4000-8000-000000000006','22334455-0000-4000-8000-000000000005',null,'Test prospect','','Please arrange a viewing for this property.',true);
do $$ begin
 if (select count(*) from public.enquiries) <> 1 then raise exception 'Duplicate enquiry accepted'; end if;
 if (select contact_email from public.enquiries limit 1) <> 'prospect-test@example.invalid' then raise exception 'Verified contact identity failure'; end if;
 begin
  update public.enquiries set status='contacted';
  if found then raise exception 'Prospect status update accepted'; end if;
 exception when insufficient_privilege then null; end;
 begin
  perform public.submit_enquiry('22334455-0000-4000-8000-000000000007','22334455-0000-4000-8000-000000000005',null,'Test prospect','','Please arrange a viewing for this property.',false);
  raise exception 'Missing consent accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.submit_enquiry('22334455-0000-4000-8000-000000000006','22334455-0000-4000-8000-000000000005',null,'Test prospect','','An altered message with reused request ID.',true);
  raise exception 'Idempotency payload conflict accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.claim_enquiry_notifications('sender@example.invalid','recipient@example.invalid');
  raise exception 'Browser worker access accepted';
 exception when insufficient_privilege then null; end;
end $$;
do $$ declare i integer; begin
 for i in 7..10 loop
  perform public.submit_enquiry(('22334455-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'22334455-0000-4000-8000-000000000005',null,'Test prospect','','Please arrange a viewing for this property.',true);
 end loop;
 begin
  perform public.submit_enquiry('22334455-0000-4000-8000-000000000011','22334455-0000-4000-8000-000000000005',null,'Test prospect','','Please arrange a viewing for this property.',true);
  raise exception 'Rate limit accepted sixth enquiry' using errcode='XX000';
 exception when raise_exception then null; end;
end $$;
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.enquiries) then raise exception 'Cross-user enquiry read accepted'; end if; end $$;
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000003',true);
update public.enquiries set status='contacted';
update public.listings set title='Changed after submission' where id='22334455-0000-4000-8000-000000000005';
do $$ begin
 if (select count(*) from public.enquiries)<>5 then raise exception 'Staff cannot read organization enquiry'; end if;
 if not exists(select 1 from public.enquiry_events where event_name='status_changed' and new_status='contacted') then raise exception 'Missing status audit'; end if;
end $$;

do $$ declare target uuid; other_target uuid; first_note jsonb; retry_note jsonb; result jsonb; begin
 select id into target from public.enquiries order by id limit 1;
 perform set_config('openhouse.test_enquiry_id',target::text,true);
 select id into other_target from public.enquiries where id<>target order by id limit 1;
 if (select count(*) from public.enquiry_staff_directory())<>2 then raise exception 'Directory exposed foreign, finance or unverified staff'; end if;
 first_note:=public.collaborate_enquiry(target,'note',null,null,'22334455-0000-4000-8000-000000000020','Private test follow-up.');
 retry_note:=public.collaborate_enquiry(target,'note',null,null,'22334455-0000-4000-8000-000000000020','Private test follow-up.');
 if first_note<>retry_note or (select count(*) from public.enquiry_staff_notes)<>1 then raise exception 'Duplicate note created'; end if;
 begin
  perform public.collaborate_enquiry(other_target,'note',null,null,'22334455-0000-4000-8000-000000000020','Private test follow-up.');
  raise exception 'Cross-enquiry note retry allowed';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.collaborate_enquiry(target,'note',null,null,'22334455-0000-4000-8000-000000000020','Changed content.');
  raise exception 'Changed retry content allowed';
 exception when invalid_parameter_value then null; end;
 result:=public.collaborate_enquiry(target,'assign','22334455-0000-4000-8000-000000000013',0,null,null);
 if (result->>'version')::integer<>1 then raise exception 'Assignment version not initialized'; end if;
 perform public.collaborate_enquiry(target,'assign','22334455-0000-4000-8000-000000000013',0,null,null);
 if (select count(*) from public.enquiry_assignment_events)<>1 then raise exception 'Retry duplicated assignment audit'; end if;
 begin
  perform public.collaborate_enquiry(target,'assign','22334455-0000-4000-8000-000000000012',1,null,null);
  raise exception 'Foreign assignee accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.collaborate_enquiry(target,'assign','22334455-0000-4000-8000-000000000014',1,null,null);
  raise exception 'Finance assignee accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.collaborate_enquiry(target,'assign','22334455-0000-4000-8000-000000000015',1,null,null);
  raise exception 'Unverified assignee accepted';
 exception when invalid_parameter_value then null; end;
 begin
  update public.enquiry_staff_notes set body='Changed';
  raise exception 'Direct note mutation accepted';
 exception when insufficient_privilege then null; end;
 begin
  delete from public.enquiry_assignment_events;
  raise exception 'Audit deletion accepted';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000013',true);
do $$ declare target uuid; begin
 select enquiry_id into target from public.enquiry_assignments limit 1;
 if (select count(*) from public.enquiry_staff_notes)<>1 then raise exception 'Colleague cannot read notes'; end if;
 begin
  perform public.collaborate_enquiry(target,'assign',null,0,null,null);
  raise exception 'Stale assignment overwrite allowed';
 exception when serialization_failure then null; end;
 perform public.collaborate_enquiry(target,'assign',null,1,null,null);
 if (select version from public.enquiry_assignments where enquiry_id=target)<>2 then raise exception 'Unassignment version failure'; end if;
 if (select count(*) from public.enquiry_assignment_events)<>2 then raise exception 'Unassignment audit missing'; end if;
end $$;
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000001',true);
do $$ begin
 if not exists(select 1 from public.enquiries) then raise exception 'Prospect history unavailable'; end if;
 if exists(select 1 from public.enquiry_staff_notes) or exists(select 1 from public.enquiry_assignments) or exists(select 1 from public.enquiry_assignment_events) then raise exception 'Internal collaboration exposed to prospect'; end if;
 begin
  perform public.enquiry_staff_directory();raise exception 'Prospect directory access allowed';
 exception when insufficient_privilege then null; end;
 begin
  perform public.collaborate_enquiry((select id from public.enquiries limit 1),'note',null,null,'22334455-0000-4000-8000-000000000021','Prospect spoofing staff.');raise exception 'Prospect collaboration allowed';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000012',true);
do $$ begin
 if exists(select 1 from public.enquiry_staff_notes) or exists(select 1 from public.enquiry_assignments) then raise exception 'Foreign organization collaboration exposed'; end if;
 if (select count(*) from public.enquiry_staff_directory())<>1 then raise exception 'Foreign directory crossed organizations'; end if;
 begin
  perform public.collaborate_enquiry(current_setting('openhouse.test_enquiry_id')::uuid,'note',null,null,'22334455-0000-4000-8000-000000000022','Foreign staff note.');raise exception 'Unavailable enquiry access allowed';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000014',true);
do $$ begin
 if exists(select 1 from public.enquiry_staff_notes) then raise exception 'Finance notes exposed'; end if;
 begin perform public.enquiry_staff_directory();raise exception 'Finance directory access';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','22334455-0000-4000-8000-000000000015',true);
do $$ begin
 if exists(select 1 from public.enquiry_staff_notes) or exists(select 1 from public.enquiry_assignments) or exists(select 1 from public.enquiry_assignment_events) then raise exception 'Unverified staff collaboration reads allowed';end if;
 begin perform public.enquiry_staff_directory();raise exception 'Unverified directory access';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: staff-only organization collaboration, restricted directory, assignment optimistic concurrency/retry/audit, immutable idempotent notes, prospect privacy and membership restrictions. All fixtures rolled back; no email sent.' as verification;
