begin;
insert into auth.users(id,email,email_confirmed_at) values
('99001122-0000-4000-8000-000000000001','first-admin@example.invalid',now()),
('99001122-0000-4000-8000-000000000002','other-admin@example.invalid',now()),
('99001122-0000-4000-8000-000000000003','unverified-admin@example.invalid',null),
('99001122-0000-4000-8000-000000000004','existing-realtor@example.invalid',now());
insert into public.organizations(id,name) values('99001122-0000-4000-8000-000000000005','Bootstrap fixtures'),('99001122-0000-4000-8000-000000000006','Other bootstrap fixtures'),('99001122-0000-4000-8000-000000000007','Empty bootstrap fixtures');
insert into public.staff_accounts(user_id,organization_id,role) values('99001122-0000-4000-8000-000000000004','99001122-0000-4000-8000-000000000005','realtor');
do $bootstrap$
declare
 target_id uuid;target_count integer;existing public.staff_accounts;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('99001122-0000-4000-8000-000000000005'::uuid::text,119));
 if not exists(select 1 from public.organizations where id='99001122-0000-4000-8000-000000000005'::uuid) then raise exception 'Approved organization does not exist';end if;
 select count(*) into target_count from auth.users where lower(email)='first-admin@example.invalid';
 if target_count<>1 then raise exception 'Exactly one approved account is required';end if;
 select id into target_id from auth.users where lower(email)='first-admin@example.invalid' and email_confirmed_at is not null and not coalesce(is_anonymous,false) for update;
 if target_id is null then raise exception 'The approved account must verify its email first';end if;
 select * into existing from public.staff_accounts where user_id=target_id for update;
 if existing.user_id is not null then
  if existing.organization_id is distinct from '99001122-0000-4000-8000-000000000005'::uuid or existing.role<>'admin' then raise exception 'Existing membership cannot be reassigned or upgraded by bootstrap';end if;
  return;
 end if;
 if exists(select 1 from public.staff_accounts where organization_id='99001122-0000-4000-8000-000000000005'::uuid and role='admin') then raise exception 'An administrator already exists; use the administrator membership workflow';end if;
 insert into public.staff_accounts(user_id,organization_id,role) values(target_id,'99001122-0000-4000-8000-000000000005'::uuid,'admin');
end
$bootstrap$;
do $bootstrap$
declare
 target_id uuid;target_count integer;existing public.staff_accounts;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('99001122-0000-4000-8000-000000000005'::uuid::text,119));
 if not exists(select 1 from public.organizations where id='99001122-0000-4000-8000-000000000005'::uuid) then raise exception 'Approved organization does not exist';end if;
 select count(*) into target_count from auth.users where lower(email)='first-admin@example.invalid';
 if target_count<>1 then raise exception 'Exactly one approved account is required';end if;
 select id into target_id from auth.users where lower(email)='first-admin@example.invalid' and email_confirmed_at is not null and not coalesce(is_anonymous,false) for update;
 if target_id is null then raise exception 'The approved account must verify its email first';end if;
 select * into existing from public.staff_accounts where user_id=target_id for update;
 if existing.user_id is not null then
  if existing.organization_id is distinct from '99001122-0000-4000-8000-000000000005'::uuid or existing.role<>'admin' then raise exception 'Existing membership cannot be reassigned or upgraded by bootstrap';end if;
  return;
 end if;
 if exists(select 1 from public.staff_accounts where organization_id='99001122-0000-4000-8000-000000000005'::uuid and role='admin') then raise exception 'An administrator already exists; use the administrator membership workflow';end if;
 insert into public.staff_accounts(user_id,organization_id,role) values(target_id,'99001122-0000-4000-8000-000000000005'::uuid,'admin');
end
$bootstrap$;
do $$ begin if(select count(*) from public.staff_accounts where organization_id='99001122-0000-4000-8000-000000000005' and role='admin')<>1 then raise exception 'Bootstrap did not create exactly one administrator';end if;end $$;
do $guard$ begin begin
declare
 target_id uuid;target_count integer;existing public.staff_accounts;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('99001122-0000-4000-8000-000000000006'::uuid::text,119));
 if not exists(select 1 from public.organizations where id='99001122-0000-4000-8000-000000000006'::uuid) then raise exception 'Approved organization does not exist';end if;
 select count(*) into target_count from auth.users where lower(email)='first-admin@example.invalid';
 if target_count<>1 then raise exception 'Exactly one approved account is required';end if;
 select id into target_id from auth.users where lower(email)='first-admin@example.invalid' and email_confirmed_at is not null and not coalesce(is_anonymous,false) for update;
 if target_id is null then raise exception 'The approved account must verify its email first';end if;
 select * into existing from public.staff_accounts where user_id=target_id for update;
 if existing.user_id is not null then
  if existing.organization_id is distinct from '99001122-0000-4000-8000-000000000006'::uuid or existing.role<>'admin' then raise exception 'Existing membership cannot be reassigned or upgraded by bootstrap';end if;
  return;
 end if;
 if exists(select 1 from public.staff_accounts where organization_id='99001122-0000-4000-8000-000000000006'::uuid and role='admin') then raise exception 'An administrator already exists; use the administrator membership workflow';end if;
 insert into public.staff_accounts(user_id,organization_id,role) values(target_id,'99001122-0000-4000-8000-000000000006'::uuid,'admin');
end;
raise exception 'Expected guard rejection';exception when raise_exception then if sqlerrm<> 'Existing membership cannot be reassigned or upgraded by bootstrap' then raise;end if;end;end $guard$;
do $guard$ begin begin
declare
 target_id uuid;target_count integer;existing public.staff_accounts;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('99001122-0000-4000-8000-000000000005'::uuid::text,119));
 if not exists(select 1 from public.organizations where id='99001122-0000-4000-8000-000000000005'::uuid) then raise exception 'Approved organization does not exist';end if;
 select count(*) into target_count from auth.users where lower(email)='existing-realtor@example.invalid';
 if target_count<>1 then raise exception 'Exactly one approved account is required';end if;
 select id into target_id from auth.users where lower(email)='existing-realtor@example.invalid' and email_confirmed_at is not null and not coalesce(is_anonymous,false) for update;
 if target_id is null then raise exception 'The approved account must verify its email first';end if;
 select * into existing from public.staff_accounts where user_id=target_id for update;
 if existing.user_id is not null then
  if existing.organization_id is distinct from '99001122-0000-4000-8000-000000000005'::uuid or existing.role<>'admin' then raise exception 'Existing membership cannot be reassigned or upgraded by bootstrap';end if;
  return;
 end if;
 if exists(select 1 from public.staff_accounts where organization_id='99001122-0000-4000-8000-000000000005'::uuid and role='admin') then raise exception 'An administrator already exists; use the administrator membership workflow';end if;
 insert into public.staff_accounts(user_id,organization_id,role) values(target_id,'99001122-0000-4000-8000-000000000005'::uuid,'admin');
end;
raise exception 'Expected guard rejection';exception when raise_exception then if sqlerrm<> 'Existing membership cannot be reassigned or upgraded by bootstrap' then raise;end if;end;end $guard$;
do $guard$ begin begin
declare
 target_id uuid;target_count integer;existing public.staff_accounts;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('99001122-0000-4000-8000-000000000005'::uuid::text,119));
 if not exists(select 1 from public.organizations where id='99001122-0000-4000-8000-000000000005'::uuid) then raise exception 'Approved organization does not exist';end if;
 select count(*) into target_count from auth.users where lower(email)='other-admin@example.invalid';
 if target_count<>1 then raise exception 'Exactly one approved account is required';end if;
 select id into target_id from auth.users where lower(email)='other-admin@example.invalid' and email_confirmed_at is not null and not coalesce(is_anonymous,false) for update;
 if target_id is null then raise exception 'The approved account must verify its email first';end if;
 select * into existing from public.staff_accounts where user_id=target_id for update;
 if existing.user_id is not null then
  if existing.organization_id is distinct from '99001122-0000-4000-8000-000000000005'::uuid or existing.role<>'admin' then raise exception 'Existing membership cannot be reassigned or upgraded by bootstrap';end if;
  return;
 end if;
 if exists(select 1 from public.staff_accounts where organization_id='99001122-0000-4000-8000-000000000005'::uuid and role='admin') then raise exception 'An administrator already exists; use the administrator membership workflow';end if;
 insert into public.staff_accounts(user_id,organization_id,role) values(target_id,'99001122-0000-4000-8000-000000000005'::uuid,'admin');
end;
raise exception 'Expected guard rejection';exception when raise_exception then if sqlerrm<> 'An administrator already exists; use the administrator membership workflow' then raise;end if;end;end $guard$;
do $guard$ begin begin
declare
 target_id uuid;target_count integer;existing public.staff_accounts;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('99001122-0000-4000-8000-000000000007'::uuid::text,119));
 if not exists(select 1 from public.organizations where id='99001122-0000-4000-8000-000000000007'::uuid) then raise exception 'Approved organization does not exist';end if;
 select count(*) into target_count from auth.users where lower(email)='unverified-admin@example.invalid';
 if target_count<>1 then raise exception 'Exactly one approved account is required';end if;
 select id into target_id from auth.users where lower(email)='unverified-admin@example.invalid' and email_confirmed_at is not null and not coalesce(is_anonymous,false) for update;
 if target_id is null then raise exception 'The approved account must verify its email first';end if;
 select * into existing from public.staff_accounts where user_id=target_id for update;
 if existing.user_id is not null then
  if existing.organization_id is distinct from '99001122-0000-4000-8000-000000000007'::uuid or existing.role<>'admin' then raise exception 'Existing membership cannot be reassigned or upgraded by bootstrap';end if;
  return;
 end if;
 if exists(select 1 from public.staff_accounts where organization_id='99001122-0000-4000-8000-000000000007'::uuid and role='admin') then raise exception 'An administrator already exists; use the administrator membership workflow';end if;
 insert into public.staff_accounts(user_id,organization_id,role) values(target_id,'99001122-0000-4000-8000-000000000007'::uuid,'admin');
end;
raise exception 'Expected guard rejection';exception when raise_exception then if sqlerrm<> 'The approved account must verify its email first' then raise;end if;end;end $guard$;
do $guard$ begin begin
declare
 target_id uuid;target_count integer;existing public.staff_accounts;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('99001122-0000-4000-8000-000000000007'::uuid::text,119));
 if not exists(select 1 from public.organizations where id='99001122-0000-4000-8000-000000000007'::uuid) then raise exception 'Approved organization does not exist';end if;
 select count(*) into target_count from auth.users where lower(email)='missing@example.invalid';
 if target_count<>1 then raise exception 'Exactly one approved account is required';end if;
 select id into target_id from auth.users where lower(email)='missing@example.invalid' and email_confirmed_at is not null and not coalesce(is_anonymous,false) for update;
 if target_id is null then raise exception 'The approved account must verify its email first';end if;
 select * into existing from public.staff_accounts where user_id=target_id for update;
 if existing.user_id is not null then
  if existing.organization_id is distinct from '99001122-0000-4000-8000-000000000007'::uuid or existing.role<>'admin' then raise exception 'Existing membership cannot be reassigned or upgraded by bootstrap';end if;
  return;
 end if;
 if exists(select 1 from public.staff_accounts where organization_id='99001122-0000-4000-8000-000000000007'::uuid and role='admin') then raise exception 'An administrator already exists; use the administrator membership workflow';end if;
 insert into public.staff_accounts(user_id,organization_id,role) values(target_id,'99001122-0000-4000-8000-000000000007'::uuid,'admin');
end;
raise exception 'Expected guard rejection';exception when raise_exception then if sqlerrm<> 'Exactly one approved account is required' then raise;end if;end;end $guard$;
do $guard$ begin begin
declare
 target_id uuid;target_count integer;existing public.staff_accounts;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('99001122-0000-4000-8000-000000000088'::uuid::text,119));
 if not exists(select 1 from public.organizations where id='99001122-0000-4000-8000-000000000088'::uuid) then raise exception 'Approved organization does not exist';end if;
 select count(*) into target_count from auth.users where lower(email)='other-admin@example.invalid';
 if target_count<>1 then raise exception 'Exactly one approved account is required';end if;
 select id into target_id from auth.users where lower(email)='other-admin@example.invalid' and email_confirmed_at is not null and not coalesce(is_anonymous,false) for update;
 if target_id is null then raise exception 'The approved account must verify its email first';end if;
 select * into existing from public.staff_accounts where user_id=target_id for update;
 if existing.user_id is not null then
  if existing.organization_id is distinct from '99001122-0000-4000-8000-000000000088'::uuid or existing.role<>'admin' then raise exception 'Existing membership cannot be reassigned or upgraded by bootstrap';end if;
  return;
 end if;
 if exists(select 1 from public.staff_accounts where organization_id='99001122-0000-4000-8000-000000000088'::uuid and role='admin') then raise exception 'An administrator already exists; use the administrator membership workflow';end if;
 insert into public.staff_accounts(user_id,organization_id,role) values(target_id,'99001122-0000-4000-8000-000000000088'::uuid,'admin');
end;
raise exception 'Expected guard rejection';exception when raise_exception then if sqlerrm<> 'Approved organization does not exist' then raise;end if;end;end $guard$;
do $$ begin if exists(select 1 from public.staff_accounts where user_id in ('99001122-0000-4000-8000-000000000002','99001122-0000-4000-8000-000000000003')) then raise exception 'Rejected bootstrap persisted a membership';end if;end $$;
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values('99001122-0000-4000-8000-000000000009','anonymous-admin@example.invalid',now(),true);
do $anonymous_guard$ begin begin
declare
 target_id uuid;target_count integer;existing public.staff_accounts;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('99001122-0000-4000-8000-000000000007'::uuid::text,119));
 if not exists(select 1 from public.organizations where id='99001122-0000-4000-8000-000000000007'::uuid) then raise exception 'Approved organization does not exist';end if;
 select count(*) into target_count from auth.users where lower(email)='anonymous-admin@example.invalid';
 if target_count<>1 then raise exception 'Exactly one approved account is required';end if;
 select id into target_id from auth.users where lower(email)='anonymous-admin@example.invalid' and email_confirmed_at is not null and not coalesce(is_anonymous,false) for update;
 if target_id is null then raise exception 'The approved account must verify its email first';end if;
 select * into existing from public.staff_accounts where user_id=target_id for update;
 if existing.user_id is not null then
  if existing.organization_id is distinct from '99001122-0000-4000-8000-000000000007'::uuid or existing.role<>'admin' then raise exception 'Existing membership cannot be reassigned or upgraded by bootstrap';end if;
  return;
 end if;
 if exists(select 1 from public.staff_accounts where organization_id='99001122-0000-4000-8000-000000000007'::uuid and role='admin') then raise exception 'An administrator already exists; use the administrator membership workflow';end if;
 insert into public.staff_accounts(user_id,organization_id,role) values(target_id,'99001122-0000-4000-8000-000000000007'::uuid,'admin');
end;
raise exception 'Anonymous administrator accepted';exception when raise_exception then if sqlerrm<>'The approved account must verify its email first' then raise;end if;end;
if exists(select 1 from public.staff_accounts where user_id='99001122-0000-4000-8000-000000000009') then raise exception 'Anonymous membership persisted';end if;end $anonymous_guard$;
rollback;
select 'PASS: first-admin verified nonanonymous account and existing-membership guards; fixtures rolled back' as verification;
