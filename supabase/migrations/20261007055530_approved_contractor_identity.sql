create table public.contractor_accounts(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),user_id uuid not null references auth.users(id),
 company_name text not null,trade_coverage text[] not null,is_active boolean not null,version integer not null check(version>0),
 created_at timestamptz not null default now(),unique(organization_id,user_id)
);
create index contractor_accounts_user_idx on public.contractor_accounts(user_id);
create index contractor_accounts_org_idx on public.contractor_accounts(organization_id,is_active,created_at desc,id);
alter table public.contractor_accounts enable row level security;
revoke all on public.contractor_accounts from public,anon,authenticated;
grant select on public.contractor_accounts to authenticated;
grant select,insert,update on public.contractor_accounts to service_role;
create policy "verified management read contractor register" on public.contractor_accounts for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create function private.verified_contractor_user() returns uuid language sql stable security definer set search_path='' as $$
 select id from auth.users where id=auth.uid() and email_confirmed_at is not null;
$$;
revoke all on function private.verified_contractor_user() from public,anon,authenticated;
grant execute on function private.verified_contractor_user() to authenticated;
create policy "verified contractors read own registrations" on public.contractor_accounts for select to authenticated using(user_id=(select private.verified_contractor_user()));
create table public.contractor_account_changes(
 id uuid primary key default gen_random_uuid(),account_id uuid not null references public.contractor_accounts(id),organization_id uuid not null references public.organizations(id),
 actor_user_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,before_record jsonb,after_record jsonb not null,
 version integer not null,reason text not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index contractor_account_changes_history_idx on public.contractor_account_changes(organization_id,account_id,created_at desc,id);
alter table public.contractor_account_changes enable row level security;
revoke all on public.contractor_account_changes from public,anon,authenticated;
grant select on public.contractor_account_changes to authenticated;
grant select,insert on public.contractor_account_changes to service_role;
create policy "verified management read contractor approval audit" on public.contractor_account_changes for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create function private.guard_contractor_identity() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if row(new.organization_id,new.user_id) is distinct from row(old.organization_id,old.user_id) then raise exception 'Contractor organization and identity are immutable' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_contractor_identity() from public,anon,authenticated;
create trigger guard_contractor_identity before update on public.contractor_accounts for each row execute function private.guard_contractor_identity();
create function private.author_contractor_account(p_request_id uuid,p_account_id uuid,p_expected_version integer,p_email text,p_company_name text,p_trade_coverage text[],p_is_active boolean,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_work_order_organization();target uuid;confirmed timestamptz;matches integer;existing public.contractor_accounts;event public.contractor_account_changes;trades text[];payload jsonb;snapshot jsonb;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified organization manager required' using errcode='42501';end if;
 if p_request_id is null or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_company_name is null or length(trim(p_company_name)) not between 2 and 160 or p_trade_coverage is null or cardinality(p_trade_coverage) not between 1 and 20 or exists(select 1 from unnest(p_trade_coverage)t where t is null or length(trim(t)) not between 1 and 80) or p_is_active is null or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Approved contractor identity coverage and change reason required' using errcode='22023';end if;
 select array_agg(t order by t) into trades from(select distinct trim(t)t from unnest(p_trade_coverage)t)s;
 payload:=jsonb_build_object('account_id',p_account_id,'version',p_expected_version,'email',lower(trim(p_email)),'company_name',trim(p_company_name),'trade_coverage',trades,'is_active',p_is_active,'reason',trim(p_reason));
 snapshot:=jsonb_build_object('company_name',trim(p_company_name),'trade_coverage',trades,'is_active',p_is_active);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_work_order_organization() is distinct from org then raise exception 'Manager authority changed' using errcode='42501';end if;
 select * into event from public.contractor_account_changes where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then
 if event.organization_id<>org or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
 return jsonb_build_object('id',event.account_id,'version',event.version);
 end if;
 if p_account_id is null then
 if p_expected_version<>0 or p_is_active is distinct from true or p_email is null or length(trim(p_email))>254 or trim(p_email) !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then raise exception 'Verified account email and new revision required' using errcode='22023';end if;
 select count(*) into matches from auth.users where lower(email)=lower(trim(p_email));if matches<>1 then raise exception 'Approved verified account required' using errcode='42501';end if;
 select id,email_confirmed_at into target,confirmed from auth.users where lower(email)=lower(trim(p_email)) for share;
 if target is null or confirmed is null then raise exception 'Approved verified account required' using errcode='42501';end if;
 insert into public.contractor_accounts(organization_id,user_id,company_name,trade_coverage,is_active,version) values(org,target,trim(p_company_name),trades,true,1) returning id into created;
 else
 if p_email is not null then raise exception 'Existing contractor identity cannot be changed' using errcode='22023';end if;
 select * into existing from public.contractor_accounts where id=p_account_id and organization_id=org for update;
 if existing.id is null then raise exception 'Organization contractor required' using errcode='42501';end if;
 if existing.version<>p_expected_version then raise exception 'Contractor changed; refresh' using errcode='40001';end if;
 if p_is_active then
 perform 1 from auth.users where id=existing.user_id and email_confirmed_at is not null for share;
 if not found then raise exception 'Verified account required for active registration' using errcode='42501';end if;
 end if;
 update public.contractor_accounts set company_name=trim(p_company_name),trade_coverage=trades,is_active=p_is_active,version=version+1 where id=existing.id returning id into created;
 end if;
 insert into public.contractor_account_changes(account_id,organization_id,actor_user_id,request_id,payload,before_record,after_record,version,reason)
 values(created,org,caller,p_request_id,payload,case when existing.id is not null then jsonb_build_object('company_name',existing.company_name,'trade_coverage',existing.trade_coverage,'is_active',existing.is_active) else null end,snapshot,p_expected_version+1,trim(p_reason));
 return jsonb_build_object('id',created,'version',p_expected_version+1);
end $$;
revoke all on function private.author_contractor_account(uuid,uuid,integer,text,text,text[],boolean,text,boolean) from public,anon,authenticated;
grant execute on function private.author_contractor_account(uuid,uuid,integer,text,text,text[],boolean,text,boolean) to authenticated;
create function public.author_contractor_account(p_request_id uuid,p_account_id uuid,p_expected_version integer,p_email text,p_company_name text,p_trade_coverage text[],p_is_active boolean,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.author_contractor_account(p_request_id,p_account_id,p_expected_version,p_email,p_company_name,p_trade_coverage,p_is_active,p_reason,p_approved);$$;
revoke all on function public.author_contractor_account(uuid,uuid,integer,text,text,text[],boolean,text,boolean) from public,anon,authenticated;
grant execute on function public.author_contractor_account(uuid,uuid,integer,text,text,text[],boolean,text,boolean) to authenticated;
