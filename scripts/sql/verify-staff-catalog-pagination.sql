begin;
insert into auth.users(id,email,email_confirmed_at) values('88990011-0000-4000-8000-000000000001','catalog-pagination@example.invalid',now());
insert into public.organizations(id,name) values('88990011-0000-4000-8000-000000000002','Catalog pagination fixtures'),('88990011-0000-4000-8000-000000000003','Foreign catalog pagination fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values('88990011-0000-4000-8000-000000000001','88990011-0000-4000-8000-000000000002','admin');
insert into public.listings(organization_id,title,area,intent,property_type,status,price_jmd)
select '88990011-0000-4000-8000-000000000002', 'Pagination Property '||i,'Kingston','rent','house','draft',100 from generate_series(1,62)i;
insert into public.realtor_profiles(organization_id,display_name,bio,service_areas,supported_intents,communication_style,guidance_style,decision_pace)
select '88990011-0000-4000-8000-000000000002','Pagination 100%_ Realtor '||i,'Draft biography',array['Kingston'],array['rent'],'direct','data-led','considered' from generate_series(1,62)i;
insert into public.realtor_profiles(organization_id,display_name,bio,service_areas,supported_intents,communication_style,guidance_style,decision_pace,is_published)
values('88990011-0000-4000-8000-000000000003','Pagination Foreign Realtor','Approved foreign professional biography.',array['Kingston'],array['rent'],'direct','data-led','considered',true);
select set_config('request.jwt.claim.sub','88990011-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 if(select count(*) from public.listings where organization_id='88990011-0000-4000-8000-000000000002' and status='draft')<>62 then raise exception 'Own listing count failed';end if;
 if(select count(*) from (select id from public.listings where organization_id='88990011-0000-4000-8000-000000000002' order by created_at desc,id offset 50 limit 25)s)<>12 then raise exception 'Final listing page failed';end if;
 if(select count(*) from public.realtor_profiles where organization_id='88990011-0000-4000-8000-000000000002' and not is_published and display_name ilike E'%100\\%\\_%')<>62 then raise exception 'Literal wildcard search failed';end if;
 if(select count(*) from (select id from public.realtor_profiles where organization_id='88990011-0000-4000-8000-000000000002' order by created_at desc,id offset 25 limit 25)s)<>25 then raise exception 'Realtor page bound failed';end if;
 if exists(select 1 from public.realtor_profiles where organization_id='88990011-0000-4000-8000-000000000002' and display_name='Pagination Foreign Realtor') then raise exception 'Public foreign profile leaked into staff scope';end if;
end $$;
reset role;
set local role anon;
do $$ begin
 if exists(select 1 from public.listings where organization_id='88990011-0000-4000-8000-000000000002') or exists(select 1 from public.realtor_profiles where organization_id='88990011-0000-4000-8000-000000000002') then raise exception 'Draft records publicly visible';end if;
end $$;
reset role;
rollback;
