create table public.finance_account_approvals(
 id uuid primary key default gen_random_uuid(),account_id uuid not null unique references public.finance_accounts(id),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index finance_account_approvals_org_idx on public.finance_account_approvals(organization_id,created_at desc,id);
alter table public.finance_account_approvals enable row level security;
revoke all on public.finance_account_approvals from public,anon,authenticated,service_role;
grant select on public.finance_account_approvals to authenticated,service_role;
create policy "finance read approved account audit" on public.finance_account_approvals for select to authenticated using(organization_id=(select private.verified_finance_organization()));
create trigger guard_finance_immutable before update or delete on public.finance_account_approvals for each row execute function private.guard_finance_immutable();
create function private.author_finance_account(p_request_id uuid,p_code text,p_name text,p_account_class text,p_reason text,p_approved boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_staff_admin_organization();event public.finance_account_approvals;payload jsonb;created uuid;code text:=upper(trim(p_code));
begin
 if caller is null or org is null then raise exception 'Verified organization administrator required' using errcode='42501';end if;
 if p_request_id is null or code is null or code !~ '^[A-Z0-9][A-Z0-9._-]{0,39}$' or p_name is null or length(trim(p_name)) not between 2 and 120 or p_account_class is null or p_account_class not in('asset','liability','equity','income','expense') or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Approved account details and reason required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_staff_admin_organization() is distinct from org then raise exception 'Administrator authority changed' using errcode='42501';end if;
 payload:=jsonb_build_object('code',code,'name',trim(p_name),'account_class',p_account_class,'reason',trim(p_reason),'approved',true);
 select * into event from public.finance_account_approvals where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then if event.organization_id<>org or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;return event.account_id;end if;
 insert into public.finance_accounts(organization_id,code,name,account_class,approved_by,approval_reason) values(org,code,trim(p_name),p_account_class,caller,trim(p_reason)) returning id into created;
 insert into public.finance_account_approvals(account_id,organization_id,actor_user_id,request_id,payload) values(created,org,caller,p_request_id,payload);
 return created;
end $$;
revoke all on function private.author_finance_account(uuid,text,text,text,text,boolean) from public,anon,authenticated;
grant execute on function private.author_finance_account(uuid,text,text,text,text,boolean) to authenticated;
create function public.author_finance_account(p_request_id uuid,p_code text,p_name text,p_account_class text,p_reason text,p_approved boolean) returns uuid language sql security invoker set search_path='' as $$select private.author_finance_account(p_request_id,p_code,p_name,p_account_class,p_reason,p_approved);$$;
revoke all on function public.author_finance_account(uuid,text,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.author_finance_account(uuid,text,text,text,text,boolean) to authenticated;
