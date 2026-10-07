begin;
insert into auth.users(id,email,email_confirmed_at) values
('77889900-0000-4000-8000-000000000001','realtor-author@example.invalid',now()),
('77889900-0000-4000-8000-000000000002','foreign-author@example.invalid',now()),
('77889900-0000-4000-8000-000000000003','unverified-author@example.invalid',null),
('77889900-0000-4000-8000-000000000004','prospect-author@example.invalid',now());
insert into public.organizations(id,name) values('77889900-0000-4000-8000-000000000005','Realtor author fixtures'),('77889900-0000-4000-8000-000000000006','Foreign author fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values
('77889900-0000-4000-8000-000000000001','77889900-0000-4000-8000-000000000005','realtor'),
('77889900-0000-4000-8000-000000000002','77889900-0000-4000-8000-000000000006','admin'),
('77889900-0000-4000-8000-000000000003','77889900-0000-4000-8000-000000000005','realtor');
select set_config('openhouse.realtor_record','{"display_name":"Approved Realtor","bio":"An approved professional biography for testing.","photo_url":null,"service_areas":[" Kingston ","Kingston"],"supported_intents":["rent"],"communication_style":"direct","guidance_style":"data-led","decision_pace":"considered","is_published":true,"organization_id":"spoof","actor_user_id":"spoof"}',true);
select set_config('request.jwt.claim.sub','77889900-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 begin perform public.author_realtor_profile(gen_random_uuid(),null,0,current_setting('openhouse.realtor_record')::jsonb,'Profile approved',false);raise exception 'Unapproved publication accepted';exception when invalid_parameter_value then null;end;
 begin perform public.author_realtor_profile(gen_random_uuid(),null,0,current_setting('openhouse.realtor_record')::jsonb||'{"service_areas":[null]}'::jsonb,'Profile approved',true);raise exception 'Invalid array accepted';exception when invalid_parameter_value then null;end;
 begin perform public.author_realtor_profile(gen_random_uuid(),null,0,current_setting('openhouse.realtor_record')::jsonb||'{"photo_url":"https://name:secret@example.invalid/p.jpg"}'::jsonb,'Profile approved',true);raise exception 'Credential photo accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('openhouse.realtor_id',public.author_realtor_profile('77889900-0000-4000-8000-000000000007',null,0,current_setting('openhouse.realtor_record')::jsonb,'Profile approved',true)->>'id',true);
do $$ begin
 if not exists(select 1 from public.realtor_profiles where id=current_setting('openhouse.realtor_id')::uuid and organization_id='77889900-0000-4000-8000-000000000005' and service_areas=array['Kingston']::text[] and authoring_revision=1) then raise exception 'Profile normalization or authority failed';end if;
 if not exists(select 1 from public.realtor_profile_changes where profile_id=current_setting('openhouse.realtor_id')::uuid and actor_user_id=auth.uid() and before_record is null and after_record->>'organization_id' is null) then raise exception 'Audit authority failed';end if;
 if public.author_realtor_profile('77889900-0000-4000-8000-000000000007',null,0,current_setting('openhouse.realtor_record')::jsonb,'Profile approved',true)->>'id'<>current_setting('openhouse.realtor_id') then raise exception 'Retry not deduplicated';end if;
 if (select count(*) from public.realtor_profile_changes)<>1 then raise exception 'Retry duplicated audit';end if;
 begin perform public.author_realtor_profile('77889900-0000-4000-8000-000000000007',null,0,current_setting('openhouse.realtor_record')::jsonb,'Changed retry reason',true);raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin update public.realtor_profiles set bio='Unauthorized edit' where id=current_setting('openhouse.realtor_id')::uuid;raise exception 'Direct edit accepted';exception when insufficient_privilege then null;end;
 begin insert into public.realtor_profile_changes(profile_id,organization_id,actor_user_id,request_id,previous_revision,new_revision,reason,approved,after_record) values(current_setting('openhouse.realtor_id')::uuid,'77889900-0000-4000-8000-000000000005',auth.uid(),gen_random_uuid(),1,2,'Forged audit',true,'{}');raise exception 'Forged audit accepted';exception when insufficient_privilege then null;end;
end $$;
select public.author_realtor_profile(gen_random_uuid(),current_setting('openhouse.realtor_id')::uuid,1,current_setting('openhouse.realtor_record')::jsonb||'{"is_published":false}'::jsonb,'Temporarily withdraw profile',false);
do $$ begin
 if not exists(select 1 from public.realtor_profile_changes where profile_id=current_setting('openhouse.realtor_id')::uuid and new_revision=2 and before_record->>'is_published'='true' and after_record->>'is_published'='false') then raise exception 'Withdrawal history missing';end if;
 begin perform public.author_realtor_profile(gen_random_uuid(),current_setting('openhouse.realtor_id')::uuid,1,current_setting('openhouse.realtor_record')::jsonb,'Stale profile edit',true);raise exception 'Stale edit accepted';exception when serialization_failure then null;end;
end $$;
select set_config('request.jwt.claim.sub','77889900-0000-4000-8000-000000000002',true);
do $$ begin
 if exists(select 1 from public.realtor_profile_changes) or exists(select 1 from public.realtor_profiles where id=current_setting('openhouse.realtor_id')::uuid) then raise exception 'Foreign private record visible';end if;
 begin perform public.author_realtor_profile(gen_random_uuid(),current_setting('openhouse.realtor_id')::uuid,2,current_setting('openhouse.realtor_record')::jsonb,'Foreign edit attempted',true);raise exception 'Foreign edit accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','77889900-0000-4000-8000-000000000003',true);
do $$ begin begin perform public.author_realtor_profile(gen_random_uuid(),null,0,current_setting('openhouse.realtor_record')::jsonb,'Unverified publication',true);raise exception 'Unverified author accepted';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','77889900-0000-4000-8000-000000000004',true);
do $$ begin
 if exists(select 1 from public.realtor_profile_changes) then raise exception 'Prospect history visible';end if;
 begin perform public.author_realtor_profile(gen_random_uuid(),null,0,current_setting('openhouse.realtor_record')::jsonb,'Prospect publication',true);raise exception 'Prospect author accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role anon;
do $$ begin
 if exists(select 1 from public.realtor_profiles where id=current_setting('openhouse.realtor_id')::uuid) then raise exception 'Withdrawn profile public';end if;
 begin perform public.author_realtor_profile(gen_random_uuid(),null,0,current_setting('openhouse.realtor_record')::jsonb,'Anonymous publication',true);raise exception 'Anonymous RPC accepted';exception when insufficient_privilege then null;end;
 begin perform 1 from public.realtor_profile_changes;raise exception 'Anonymous audit access';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
