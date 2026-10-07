alter table public.staff_accounts add column membership_revision uuid not null default gen_random_uuid();
create function private.verified_staff_admin_organization() returns uuid language sql stable security definer set search_path='' as $$
 select s.organization_id from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=auth.uid() and s.role='admin' and u.email_confirmed_at is not null;
$$;
revoke all on function private.verified_staff_admin_organization() from public,anon,authenticated;
grant execute on function private.verified_staff_admin_organization() to authenticated;
create policy "verified administrators read organization memberships" on public.staff_accounts for select to authenticated using(organization_id=(select private.verified_staff_admin_organization()));
create table public.staff_membership_changes(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),
 target_user_id uuid not null references auth.users(id),target_email text not null,request_id uuid not null,previous_role text,new_role text,
 previous_revision uuid,new_revision uuid,reason text not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id),
 check(previous_role is null or previous_role in('admin','realtor','manager','finance')),check(new_role is null or new_role in('admin','realtor','manager','finance'))
);
create index staff_membership_changes_org_idx on public.staff_membership_changes(organization_id,created_at desc,id);
alter table public.staff_membership_changes enable row level security;
revoke all on public.staff_membership_changes from public,anon,authenticated;
grant select on public.staff_membership_changes to authenticated;
grant select,insert on public.staff_membership_changes to service_role;
create policy "verified administrators read membership audit" on public.staff_membership_changes for select to authenticated using(organization_id=(select private.verified_staff_admin_organization()));
create function private.manage_staff_membership(p_request_id uuid,p_email text,p_role text,p_expected_revision uuid,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_staff_admin_organization();target uuid;confirmed timestamptz;existing public.staff_accounts;audit public.staff_membership_changes;next_revision uuid;email_normalized text:=lower(trim(p_email));matches integer;
begin
 if caller is null or org is null then raise exception 'Verified administrator required' using errcode='42501';end if;
 if p_request_id is null or p_email is null or length(email_normalized) not between 3 and 254 or email_normalized !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' or (p_role is not null and p_role not in('admin','realtor','manager','finance')) or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Approved membership change and reason required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_staff_admin_organization() is distinct from org then raise exception 'Administrator access changed' using errcode='42501';end if;
 select * into audit from public.staff_membership_changes where actor_user_id=caller and request_id=p_request_id;
 if audit.id is not null then
 if audit.organization_id<>org or audit.target_email<>email_normalized or audit.new_role is distinct from p_role or audit.previous_revision is distinct from p_expected_revision or audit.reason<>trim(p_reason) then raise exception 'Request ID already used' using errcode='22023';end if;
 return jsonb_build_object('user_id',audit.target_user_id,'role',audit.new_role,'revision',audit.new_revision);
 end if;
 select count(*) into matches from auth.users where lower(email)=email_normalized;
 if matches<>1 then raise exception 'Approved account unavailable' using errcode='42501';end if;
 select id,email_confirmed_at into target,confirmed from auth.users where lower(email)=email_normalized for update;
 if target is null or (p_role is not null and confirmed is null) then raise exception 'Approved verified account required' using errcode='42501';end if;
 select * into existing from public.staff_accounts where user_id=target for update;
 if existing.user_id is not null and existing.organization_id is distinct from org then raise exception 'Organization membership required' using errcode='42501';end if;
 if existing.membership_revision is distinct from p_expected_revision then raise exception 'Membership changed; refresh' using errcode='40001';end if;
 if p_role is null and existing.user_id is null then raise exception 'Current membership required' using errcode='42501';end if;
 if existing.role='admin' and p_role is distinct from 'admin' and not exists(select 1 from public.staff_accounts s join auth.users u on u.id=s.user_id where s.organization_id=org and s.role='admin' and s.user_id<>target and u.email_confirmed_at is not null) then raise exception 'Keep another verified administrator before removing this role' using errcode='23505';end if;
 if p_role is null then delete from public.staff_accounts where user_id=target;
 else
 next_revision:=gen_random_uuid();
 insert into public.staff_accounts(user_id,organization_id,role,membership_revision) values(target,org,p_role,next_revision)
 on conflict(user_id) do update set role=excluded.role,membership_revision=excluded.membership_revision;
 end if;
 insert into public.staff_membership_changes(organization_id,actor_user_id,target_user_id,target_email,request_id,previous_role,new_role,previous_revision,new_revision,reason)
 values(org,caller,target,email_normalized,p_request_id,existing.role,p_role,existing.membership_revision,next_revision,trim(p_reason));
 return jsonb_build_object('user_id',target,'role',p_role,'revision',next_revision);
end $$;
revoke all on function private.manage_staff_membership(uuid,text,text,uuid,text,boolean) from public,anon,authenticated;
grant execute on function private.manage_staff_membership(uuid,text,text,uuid,text,boolean) to authenticated;
create function public.manage_staff_membership(p_request_id uuid,p_email text,p_role text,p_expected_revision uuid,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.manage_staff_membership(p_request_id,p_email,p_role,p_expected_revision,p_reason,p_approved);$$;
revoke all on function public.manage_staff_membership(uuid,text,text,uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.manage_staff_membership(uuid,text,text,uuid,text,boolean) to authenticated;
create function private.staff_membership_directory(p_page integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid:=private.verified_staff_admin_organization();total integer;page integer;rows jsonb;
begin
 if auth.uid() is null or org is null then raise exception 'Verified administrator required' using errcode='42501';end if;
 if p_page is null or p_page not between 1 and 100000 then raise exception 'Valid page required' using errcode='22023';end if;
 select count(*) into total from public.staff_accounts where organization_id=org;
 page:=least(p_page,greatest(1,(total+24)/25));
 select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) into rows from(
 select s.user_id,s.role,s.membership_revision,u.email,(u.email_confirmed_at is not null) as verified
 from public.staff_accounts s join auth.users u on u.id=s.user_id where s.organization_id=org order by lower(u.email),s.user_id limit 25 offset (page-1)*25
 )r;
 return jsonb_build_object('rows',rows,'total',total,'page',page,'pages',greatest(1,(total+24)/25));
end $$;
revoke all on function private.staff_membership_directory(integer) from public,anon,authenticated;
grant execute on function private.staff_membership_directory(integer) to authenticated;
create function public.staff_membership_directory(p_page integer) returns jsonb language sql security invoker set search_path='' as $$select private.staff_membership_directory(p_page);$$;
revoke all on function public.staff_membership_directory(integer) from public,anon,authenticated;
grant execute on function public.staff_membership_directory(integer) to authenticated;
