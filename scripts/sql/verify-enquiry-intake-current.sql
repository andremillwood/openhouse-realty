begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('77990011-0000-4000-8000-000000000001','enquiry-owner@example.invalid',now()),
 ('77990011-0000-4000-8000-000000000002','enquiry-other@example.invalid',now()),
 ('77990011-0000-4000-8000-000000000003','enquiry-unverified@example.invalid',null);
insert into public.organizations(id,name) values ('77990011-0000-4000-8000-000000000004','Rolled back enquiry fixture');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values
 ('77990011-0000-4000-8000-000000000005','77990011-0000-4000-8000-000000000004','Enquiry fixture','Test area','rent','house','published',100,'A sufficiently detailed description for this rolled back test.','https://example.invalid/fixture.jpg');
insert into public.realtor_profiles(id,organization_id,display_name,bio,service_areas,supported_intents,communication_style,guidance_style,decision_pace,is_published) values
 ('77990011-0000-4000-8000-000000000006','77990011-0000-4000-8000-000000000004','Fixture Realtor','Rolled back approved-length profile',array['Test area'],array['rent'],'direct','data-led','considered',true);
select set_config('request.jwt.claim.sub','77990011-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ declare a uuid; b uuid; begin
 a:=public.submit_enquiry('77990011-0000-4000-8000-000000000007','77990011-0000-4000-8000-000000000005',null,'Client Name','','Please introduce me to the property team.',true);
 b:=public.submit_enquiry('77990011-0000-4000-8000-000000000007','77990011-0000-4000-8000-000000000005',null,'Client Name','','Please introduce me to the property team.',true);
 if a is distinct from b then raise exception 'Retry changed enquiry ID'; end if;
 perform public.submit_enquiry('77990011-0000-4000-8000-000000000008',null,'77990011-0000-4000-8000-000000000006','Client Name','','Please introduce me directly to this realtor.',true);
 if (select count(*) from public.enquiries where user_id=auth.uid())<>2 then raise exception 'Target intake count'; end if;
 if exists(select 1 from public.enquiries where user_id=auth.uid() and (contact_email<>'enquiry-owner@example.invalid' or organization_id<>'77990011-0000-4000-8000-000000000004')) then raise exception 'Trusted identity/scope failure'; end if;
 begin perform public.submit_enquiry('77990011-0000-4000-8000-000000000007',null,'77990011-0000-4000-8000-000000000006','Client Name','','Please introduce me to the property team.',true);raise exception 'Changed retry accepted' using errcode='XX000';exception when invalid_parameter_value then null;end;
 begin perform public.submit_enquiry('77990011-0000-4000-8000-000000000009',null,'77990011-0000-4000-8000-000000000006','Client Name','','Please introduce me directly to this realtor.',false);raise exception 'No consent accepted' using errcode='XX000';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','77990011-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.enquiries where organization_id='77990011-0000-4000-8000-000000000004') then raise exception 'Other prospect read accepted';end if;end $$;
select set_config('request.jwt.claim.sub','77990011-0000-4000-8000-000000000003',true);
do $$ begin begin perform public.submit_enquiry('77990011-0000-4000-8000-000000000009',null,'77990011-0000-4000-8000-000000000006','Client Name','','Please introduce me directly to this realtor.',true);raise exception 'Unverified intake accepted' using errcode='XX000';exception when insufficient_privilege then null;end;end $$;
reset role;
update public.realtor_profiles set is_published=false where id='77990011-0000-4000-8000-000000000006';
select set_config('request.jwt.claim.sub','77990011-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 perform public.submit_enquiry('77990011-0000-4000-8000-000000000008',null,'77990011-0000-4000-8000-000000000006','Client Name','','Please introduce me directly to this realtor.',true);
 begin perform public.submit_enquiry('77990011-0000-4000-8000-000000000009',null,'77990011-0000-4000-8000-000000000006','Client Name','','Please introduce me directly to this realtor.',true);raise exception 'Unpublished new intake accepted' using errcode='XX000';exception when invalid_parameter_value then null;end;
end $$;
reset role;
do $$ begin
 if (select count(*) from private.notification_outbox n join public.enquiries e on e.id=n.enquiry_id where e.organization_id='77990011-0000-4000-8000-000000000004')<>2 then raise exception 'Missing/duplicate transactional notices';end if;
 if (select count(*) from public.enquiry_events v join public.enquiries e on e.id=v.enquiry_id where e.organization_id='77990011-0000-4000-8000-000000000004' and v.event_name='submitted')<>2 then raise exception 'Missing/duplicate submission audit';end if;
end $$;
rollback;
select 'PASS: listing/realtor intake, exact retry, trusted identity, consent, private reads, verified account, unpublished target denial and retry recovery. Fixtures rolled back; no delivery invoked.' as verification;
