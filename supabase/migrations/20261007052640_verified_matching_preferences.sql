alter table public.realtor_match_preferences add column revision uuid not null default gen_random_uuid();
revoke insert,update,delete on public.realtor_match_preferences from authenticated;
drop policy "users manage their own matching preferences" on public.realtor_match_preferences;
create policy "users read own matching preferences" on public.realtor_match_preferences for select to authenticated using((select auth.uid())=user_id);
create function private.manage_matching_preferences(p_action text,p_expected_revision uuid,p_preferences jsonb,p_consent boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();existing public.realtor_match_preferences;next_revision uuid:=gen_random_uuid();
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) then raise exception 'Verified account required' using errcode='42501';end if;
 if p_action is null or p_action not in ('save','delete') then raise exception 'Invalid action' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,89));
 select * into existing from public.realtor_match_preferences where user_id=caller;
 if existing.revision is distinct from p_expected_revision then raise exception 'Preferences changed; refresh before retrying' using errcode='40001';end if;
 if p_action='delete' then
  delete from public.realtor_match_preferences where user_id=caller;
  return jsonb_build_object('revision',null,'status','deleted');
 end if;
 if p_consent is distinct from true or p_preferences is null or jsonb_typeof(p_preferences)<>'object'
 or coalesce(p_preferences->>'intent','') not in ('buy','rent','sell')
 or coalesce(p_preferences->>'communication_style','') not in ('thoughtful','direct','collaborative')
 or coalesce(p_preferences->>'guidance_style','') not in ('step-by-step','data-led','independent')
 or coalesce(p_preferences->>'decision_pace','') not in ('considered','decisive','flexible')
 or length(trim(coalesce(p_preferences->>'preferred_area',''))) not between 1 and 120
 then raise exception 'Valid preferences and explicit consent required' using errcode='22023';end if;
 insert into public.realtor_match_preferences(user_id,intent,preferred_area,communication_style,guidance_style,decision_pace,consented_at,revision)
 values(caller,p_preferences->>'intent',trim(p_preferences->>'preferred_area'),p_preferences->>'communication_style',p_preferences->>'guidance_style',p_preferences->>'decision_pace',now(),next_revision)
 on conflict(user_id) do update set intent=excluded.intent,preferred_area=excluded.preferred_area,communication_style=excluded.communication_style,guidance_style=excluded.guidance_style,decision_pace=excluded.decision_pace,consented_at=excluded.consented_at,revision=excluded.revision;
 return jsonb_build_object('revision',next_revision,'status','saved');
end $$;
revoke all on function private.manage_matching_preferences(text,uuid,jsonb,boolean) from public,anon,authenticated;
grant execute on function private.manage_matching_preferences(text,uuid,jsonb,boolean) to authenticated;
create function public.manage_matching_preferences(p_action text,p_expected_revision uuid,p_preferences jsonb,p_consent boolean) returns jsonb language sql security invoker set search_path='' as $$select private.manage_matching_preferences(p_action,p_expected_revision,p_preferences,p_consent);$$;
revoke all on function public.manage_matching_preferences(text,uuid,jsonb,boolean) from public,anon,authenticated;
grant execute on function public.manage_matching_preferences(text,uuid,jsonb,boolean) to authenticated;
