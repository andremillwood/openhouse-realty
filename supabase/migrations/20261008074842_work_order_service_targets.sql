-- Explicit staff targets are operational planning, not proof of response or completion.
create function private.verified_service_target_organization() returns uuid language sql stable security definer set search_path='' as $$
 select s.organization_id from public.staff_accounts s join auth.users u on u.id=s.user_id
 where s.user_id=auth.uid() and s.role in('admin','manager') and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false);
$$;
revoke all on function private.verified_service_target_organization() from public,anon,authenticated,service_role;
grant execute on function private.verified_service_target_organization() to authenticated;
create table public.work_order_service_target_events(
 id uuid primary key default gen_random_uuid(),work_order_id uuid not null references public.work_orders(id),organization_id uuid not null references public.organizations(id),
 work_order_version integer not null check(work_order_version>0),kind text not null check(kind in('response','resolution')),version integer not null check(version>0),
 action text not null check(action in('set','clear')),due_at timestamptz,
 reason text not null check(length(reason) between 5 and 500),actor_user_id uuid not null references auth.users(id),request_id uuid not null,
 created_at timestamptz not null default statement_timestamp(),unique(work_order_id,kind,version),unique(actor_user_id,request_id),
 check((action='set' and due_at is not null and due_at>='2000-01-01'::timestamptz and due_at<'2100-01-01'::timestamptz) or (action='clear' and due_at is null))
);
alter table public.work_order_service_target_events enable row level security;
revoke all on public.work_order_service_target_events from public,anon,authenticated,service_role;
grant select on public.work_order_service_target_events to authenticated;
create policy "verified managers read service targets" on public.work_order_service_target_events for select to authenticated using(
 organization_id=(select private.verified_service_target_organization()) and exists(select 1 from public.work_orders w where w.id=work_order_id and w.organization_id=work_order_service_target_events.organization_id)
);
create trigger immutable_work_service_targets before update or delete on public.work_order_service_target_events for each row execute function private.guard_finance_immutable();
create function private.record_work_order_service_target(p_work_order_id uuid,p_expected_work_order_version integer,p_kind text,p_expected_version integer,p_action text,p_due_at timestamptz,p_reason text,p_approved boolean,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_service_target_organization();w public.work_orders;r public.work_order_service_target_events;current_version integer;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified organization manager required' using errcode='42501';end if;
 if p_work_order_id is null or p_request_id is null or p_expected_work_order_version is null or p_expected_work_order_version not between 1 and 2147483645 or p_expected_version is null or p_expected_version not between 0 and 2147483645 or p_kind is null or p_kind not in('response','resolution') or p_action is null or p_action not in('set','clear') or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true or (p_action='set' and (p_due_at is null or p_due_at<'2000-01-01'::timestamptz or p_due_at>='2100-01-01'::timestamptz)) or (p_action='clear' and p_due_at is not null) then raise exception 'Approved explained target and revisions required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 perform 1 from auth.users where id=caller and email_confirmed_at is not null and not coalesce(is_anonymous,false) for share;
 if not found or private.verified_service_target_organization() is distinct from org then raise exception 'Manager authority changed' using errcode='42501';end if;
 select * into w from public.work_orders where id=p_work_order_id and organization_id=org for update;
 if w.id is null then raise exception 'Organization work order required' using errcode='42501';end if;
 select * into r from public.work_order_service_target_events where actor_user_id=caller and request_id=p_request_id;
 if r.id is not null then
  if r.work_order_id<>w.id or r.work_order_version<>p_expected_work_order_version or r.kind<>p_kind or r.version<>p_expected_version+1 or r.action<>p_action or r.due_at is distinct from p_due_at or r.reason<>trim(p_reason) then raise exception 'Request reference already used' using errcode='22023';end if;
  return jsonb_build_object('id',r.id,'work_order_id',w.id,'work_order_version',r.work_order_version,'kind',r.kind,'version',r.version,'action',r.action,'due_at',r.due_at);
 end if;
 if w.revision<>p_expected_work_order_version or w.status in('completed','closed','cancelled') then raise exception 'Work order changed or closed' using errcode='40001';end if;
 if p_action='set' and p_due_at<=statement_timestamp() then raise exception 'New target must be in the future' using errcode='22023';end if;
 select coalesce(max(version),0) into current_version from public.work_order_service_target_events where work_order_id=w.id and kind=p_kind;
 if current_version<>p_expected_version then raise exception 'Target changed; refresh' using errcode='40001';end if;
 insert into public.work_order_service_target_events(work_order_id,organization_id,work_order_version,kind,version,action,due_at,reason,actor_user_id,request_id)
 values(w.id,org,w.revision,p_kind,current_version+1,p_action,p_due_at,trim(p_reason),caller,p_request_id) returning id into created;
 return jsonb_build_object('id',created,'work_order_id',w.id,'work_order_version',w.revision,'kind',p_kind,'version',current_version+1,'action',p_action,'due_at',p_due_at);
end $$;
revoke all on function private.record_work_order_service_target(uuid,integer,text,integer,text,timestamptz,text,boolean,uuid) from public,anon,authenticated,service_role;
grant execute on function private.record_work_order_service_target(uuid,integer,text,integer,text,timestamptz,text,boolean,uuid) to authenticated;
create function public.record_work_order_service_target(p_work_order_id uuid,p_expected_work_order_version integer,p_kind text,p_expected_version integer,p_action text,p_due_at timestamptz,p_reason text,p_approved boolean,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select private.record_work_order_service_target(p_work_order_id,p_expected_work_order_version,p_kind,p_expected_version,p_action,p_due_at,p_reason,p_approved,p_request_id);$$;
revoke all on function public.record_work_order_service_target(uuid,integer,text,integer,text,timestamptz,text,boolean,uuid) from public,anon,authenticated,service_role;
grant execute on function public.record_work_order_service_target(uuid,integer,text,integer,text,timestamptz,text,boolean,uuid) to authenticated;
