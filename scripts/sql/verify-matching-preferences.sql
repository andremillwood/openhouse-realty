begin;
insert into auth.users(id,email,email_confirmed_at) values
('66889900-0000-4000-8000-000000000001','matching-owner@example.invalid',now()),
('66889900-0000-4000-8000-000000000002','matching-other@example.invalid',now()),
('66889900-0000-4000-8000-000000000003','matching-unverified@example.invalid',null);
select set_config('request.jwt.claim.sub','66889900-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('openhouse.match_result',public.manage_matching_preferences('save',null,'{"intent":"buy","preferred_area":"Kingston","communication_style":"direct","guidance_style":"data-led","decision_pace":"considered","user_id":"66889900-0000-4000-8000-000000000002","consented_at":"2000-01-01"}',true)::text,true);
do $$ declare saved_revision uuid:=(current_setting('openhouse.match_result')::jsonb->>'revision')::uuid;begin
 if current_setting('openhouse.match_result')::jsonb->>'status'<>'saved' or saved_revision is null then raise exception 'Save result incorrect';end if;
 if not exists(select 1 from public.realtor_match_preferences where user_id=auth.uid() and preferred_area='Kingston' and revision=saved_revision and consented_at>now()-interval '1 minute') then raise exception 'Owner or consent binding incorrect';end if;
 begin perform public.manage_matching_preferences('save',null,'{"intent":"rent","preferred_area":"Kingston","communication_style":"direct","guidance_style":"data-led","decision_pace":"considered"}',true);raise exception 'Stale save accepted';exception when serialization_failure then null;end;
 begin perform public.manage_matching_preferences('save',saved_revision,'{"intent":"rent","preferred_area":"Kingston","communication_style":"direct","guidance_style":"data-led","decision_pace":"considered"}',false);raise exception 'Unapproved preference save accepted';exception when invalid_parameter_value then null;end;
 begin perform public.manage_matching_preferences('delete',gen_random_uuid(),null,false);raise exception 'Stale deletion accepted';exception when serialization_failure then null;end;
end $$;
select set_config('request.jwt.claim.sub','66889900-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.realtor_match_preferences) then raise exception 'Other account preferences visible';end if;end $$;
select set_config('request.jwt.claim.sub','66889900-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.manage_matching_preferences('save',null,'{"intent":"buy","preferred_area":"Kingston","communication_style":"direct","guidance_style":"data-led","decision_pace":"considered"}',true);raise exception 'Unverified save accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','66889900-0000-4000-8000-000000000001',true);
select public.manage_matching_preferences('delete',(current_setting('openhouse.match_result')::jsonb->>'revision')::uuid,null,false);
do $$ begin if exists(select 1 from public.realtor_match_preferences) then raise exception 'Deleted preference remains visible';end if;end $$;
reset role;
do $$ begin
 if exists(select 1 from public.realtor_match_preferences where user_id in('66889900-0000-4000-8000-000000000001','66889900-0000-4000-8000-000000000002','66889900-0000-4000-8000-000000000003')) then raise exception 'Deleted or spoofed owner preference retained';end if;
 if has_table_privilege('authenticated','public.realtor_match_preferences','INSERT') or has_table_privilege('authenticated','public.realtor_match_preferences','UPDATE') or has_table_privilege('authenticated','public.realtor_match_preferences','DELETE') then raise exception 'Direct client writes open';end if;
 if position('for share' in pg_get_functiondef('private.manage_matching_preferences(text,uuid,jsonb,boolean)'::regprocedure))=0 then raise exception 'Verified account commit lock absent';end if;
end $$;
rollback;
