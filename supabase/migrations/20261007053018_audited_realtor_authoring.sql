alter table public.realtor_profiles add column authoring_revision integer not null default 0 check(authoring_revision>=0);
create table public.realtor_profile_changes(
 id uuid primary key default gen_random_uuid(),profile_id uuid not null references public.realtor_profiles(id),
 organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,
 previous_revision integer not null,new_revision integer not null,reason text not null,approved boolean not null,
 before_record jsonb,after_record jsonb not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index realtor_profile_changes_history_idx on public.realtor_profile_changes(organization_id,profile_id,created_at desc,id);
alter table public.realtor_profile_changes enable row level security;
revoke all on public.realtor_profile_changes from public,anon,authenticated;
grant select on public.realtor_profile_changes to authenticated;
grant select,insert on public.realtor_profile_changes to service_role;
create policy "verified catalog staff read own realtor changes" on public.realtor_profile_changes for select to authenticated using(organization_id=(select private.verified_catalog_organization()));
revoke insert,update on public.realtor_profiles from authenticated;
create function private.author_realtor_profile(p_request_id uuid,p_profile_id uuid,p_expected_revision integer,p_record jsonb,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_catalog_organization();prior public.realtor_profiles;change public.realtor_profile_changes;created uuid;normalized jsonb;areas text[];intents text[];key text;published boolean;photo text;
begin
 if caller is null or org is null then raise exception 'Verified catalog staff required' using errcode='42501';end if;
 if p_request_id is null or p_expected_revision is null or p_expected_revision<0 or p_expected_revision>=2147483647 or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_record is null or jsonb_typeof(p_record)<>'object' then raise exception 'Valid profile revision and change reason required' using errcode='22023';end if;
 foreach key in array array['display_name','bio','communication_style','guidance_style','decision_pace'] loop
 if jsonb_typeof(p_record->key) is distinct from 'string' then raise exception 'Text profile fields required' using errcode='22023';end if;
 end loop;
 if length(trim(p_record->>'display_name')) not between 2 and 160 or length(trim(p_record->>'bio'))>5000
 or p_record->>'communication_style' not in ('thoughtful','direct','collaborative')
 or p_record->>'guidance_style' not in ('step-by-step','data-led','independent')
 or p_record->>'decision_pace' not in ('considered','decisive','flexible')
 or jsonb_typeof(p_record->'is_published') is distinct from 'boolean'
 then raise exception 'Valid biography and working styles required' using errcode='22023';end if;
 foreach key in array array['service_areas','supported_intents'] loop
 if jsonb_typeof(p_record->key) is distinct from 'array' then raise exception 'Service arrays required' using errcode='22023';end if;
 if jsonb_array_length(p_record->key)>50 or exists(select 1 from jsonb_array_elements(p_record->key) a where jsonb_typeof(a) is distinct from 'string' or length(trim(a#>>'{}')) not between 1 and 120) then raise exception 'Bounded service arrays required' using errcode='22023';end if;
 end loop;
 select coalesce(array_agg(value order by value),'{}'::text[]) into areas from(select distinct trim(value) value from jsonb_array_elements_text(p_record->'service_areas')) a;
 select coalesce(array_agg(value order by value),'{}'::text[]) into intents from(select distinct trim(value) value from jsonb_array_elements_text(p_record->'supported_intents')) a;
 if not(intents<@array['buy','rent','sell']::text[]) then raise exception 'Valid service intents required' using errcode='22023';end if;
 if p_record->'photo_url' is not null and p_record->'photo_url'<>'null'::jsonb and jsonb_typeof(p_record->'photo_url') is distinct from 'string' then raise exception 'HTTPS photo required' using errcode='22023';end if;
 photo:=nullif(trim(p_record->>'photo_url'),'');
 if photo is not null and (length(photo)>2048 or photo !~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?([/?#][^[:space:]]*)?$') then raise exception 'HTTPS photo required' using errcode='22023';end if;
 published:=(p_record->>'is_published')::boolean;
 if published and (p_approved is distinct from true or length(trim(p_record->>'bio'))<20 or cardinality(areas)=0 or cardinality(intents)=0) then raise exception 'Explicit approval and complete profile required' using errcode='22023';end if;
 normalized:=jsonb_build_object('display_name',trim(p_record->>'display_name'),'bio',trim(p_record->>'bio'),'photo_url',photo,'service_areas',areas,'supported_intents',intents,'communication_style',p_record->>'communication_style','guidance_style',p_record->>'guidance_style','decision_pace',p_record->>'decision_pace','is_published',published);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,98));
 select * into change from public.realtor_profile_changes where actor_user_id=caller and request_id=p_request_id;
 if change.id is not null then
 if change.organization_id<>org or change.previous_revision<>p_expected_revision or (p_profile_id is not null and change.profile_id<>p_profile_id) or (p_profile_id is null and change.before_record is not null) or change.after_record<>normalized or change.reason<>trim(p_reason) or change.approved<>coalesce(p_approved,false) then raise exception 'Request ID already used' using errcode='22023';end if;
 return jsonb_build_object('id',change.profile_id,'revision',change.new_revision);
 end if;
 if p_profile_id is not null then
 select * into prior from public.realtor_profiles where id=p_profile_id and organization_id=org for update;
 if prior.id is null then raise exception 'Organization profile required' using errcode='42501';end if;
 if prior.authoring_revision<>p_expected_revision then raise exception 'Profile changed; refresh' using errcode='40001';end if;
 update public.realtor_profiles set display_name=normalized->>'display_name',bio=normalized->>'bio',photo_url=photo,service_areas=areas,supported_intents=intents,communication_style=normalized->>'communication_style',guidance_style=normalized->>'guidance_style',decision_pace=normalized->>'decision_pace',is_published=published,authoring_revision=authoring_revision+1 where id=prior.id returning id into created;
 else
 if p_expected_revision<>0 then raise exception 'New profile revision must be zero' using errcode='40001';end if;
 insert into public.realtor_profiles(organization_id,display_name,bio,photo_url,service_areas,supported_intents,communication_style,guidance_style,decision_pace,is_published,authoring_revision)
 values(org,normalized->>'display_name',normalized->>'bio',photo,areas,intents,normalized->>'communication_style',normalized->>'guidance_style',normalized->>'decision_pace',published,1) returning id into created;
 end if;
 insert into public.realtor_profile_changes(profile_id,organization_id,actor_user_id,request_id,previous_revision,new_revision,reason,approved,before_record,after_record)
 values(created,org,caller,p_request_id,p_expected_revision,p_expected_revision+1,trim(p_reason),coalesce(p_approved,false),case when prior.id is not null then to_jsonb(prior)-'id'-'organization_id'-'created_at'-'authoring_revision' else null end,normalized);
 return jsonb_build_object('id',created,'revision',p_expected_revision+1);
end $$;
revoke all on function private.author_realtor_profile(uuid,uuid,integer,jsonb,text,boolean) from public,anon,authenticated;
grant execute on function private.author_realtor_profile(uuid,uuid,integer,jsonb,text,boolean) to authenticated;
create function public.author_realtor_profile(p_request_id uuid,p_profile_id uuid,p_expected_revision integer,p_record jsonb,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.author_realtor_profile(p_request_id,p_profile_id,p_expected_revision,p_record,p_reason,p_approved);$$;
revoke all on function public.author_realtor_profile(uuid,uuid,integer,jsonb,text,boolean) from public,anon,authenticated;
grant execute on function public.author_realtor_profile(uuid,uuid,integer,jsonb,text,boolean) to authenticated;
