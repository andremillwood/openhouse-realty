create function private.security_property_authorized(p_property_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.property_security_assignments s join auth.users u on u.id=s.user_id where s.property_id=p_property_id and s.user_id=auth.uid() and s.is_active and u.email_confirmed_at is not null);
$$;
revoke all on function private.security_property_authorized(uuid) from public,anon,authenticated;
grant execute on function private.security_property_authorized(uuid) to authenticated;
create table public.contractor_presence(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),property_id uuid not null references public.properties(id),visit_id uuid not null unique references public.contractor_visits(id),permit_id uuid not null references public.contractor_entry_permits(id),contractor_user_id uuid not null references auth.users(id),
 state text not null check(state in('on_site','exited')),checked_in_at timestamptz not null,checked_out_at timestamptz,version integer not null default 1 check(version>0),check((state='exited')=(checked_out_at is not null)),check(checked_out_at is null or checked_out_at>=checked_in_at)
);
create index contractor_presence_property_idx on public.contractor_presence(property_id,state,checked_in_at desc,id);
create index contractor_presence_org_idx on public.contractor_presence(organization_id,checked_in_at desc,id);
create index contractor_presence_user_idx on public.contractor_presence(contractor_user_id,checked_in_at desc,id);
alter table public.contractor_presence enable row level security;
revoke all on public.contractor_presence from public,anon,authenticated;
grant select on public.contractor_presence to authenticated;
grant select,insert,update on public.contractor_presence to service_role;
create policy "management read presence" on public.contractor_presence for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create policy "property security read presence" on public.contractor_presence for select to authenticated using(private.security_property_authorized(property_id));
create policy "contractors read own presence" on public.contractor_presence for select to authenticated using(contractor_user_id=(select private.verified_contractor_user()));
create table public.contractor_presence_changes(
 id uuid primary key default gen_random_uuid(),presence_id uuid not null references public.contractor_presence(id),organization_id uuid not null references public.organizations(id),property_id uuid not null references public.properties(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,action text not null,previous_state text,new_state text not null,version integer not null,reason text not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index contractor_presence_changes_history_idx on public.contractor_presence_changes(organization_id,presence_id,created_at desc,id);
create index contractor_presence_changes_security_idx on public.contractor_presence_changes(property_id,presence_id,created_at desc,id);
alter table public.contractor_presence_changes enable row level security;
revoke all on public.contractor_presence_changes from public,anon,authenticated;
grant select on public.contractor_presence_changes to authenticated;
grant select,insert on public.contractor_presence_changes to service_role;
create policy "management read presence audit" on public.contractor_presence_changes for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create policy "property security read presence audit" on public.contractor_presence_changes for select to authenticated using(private.security_property_authorized(property_id));
alter table public.work_order_changes drop constraint work_order_changes_action_check;
alter table public.work_order_changes add constraint work_order_changes_action_check check(action in('create','triage','cancel','assign','unassign','schedule','unschedule','check_in','check_out'));
create function private.guard_presence_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and row(new.organization_id,new.property_id,new.visit_id,new.permit_id,new.contractor_user_id,new.checked_in_at) is distinct from row(old.organization_id,old.property_id,old.visit_id,old.permit_id,old.contractor_user_id,old.checked_in_at) then raise exception 'Presence identity and arrival time immutable' using errcode='23505';end if;
 if not exists(select 1 from public.contractor_entry_permits p join public.contractor_visits v on v.id=p.visit_id where p.id=new.permit_id and v.id=new.visit_id and p.organization_id=new.organization_id and v.property_id=new.property_id and p.contractor_user_id=new.contractor_user_id) then raise exception 'Presence must match permit assignment' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_presence_binding() from public,anon,authenticated;
create trigger guard_presence_binding before insert or update on public.contractor_presence for each row execute function private.guard_presence_binding();
create function private.record_contractor_presence(p_request_id uuid,p_action text,p_permit_id uuid,p_presence_id uuid,p_expected_version integer,p_identity_checked boolean,p_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();permit public.contractor_entry_permits;visit public.contractor_visits;offer public.contractor_work_offers;job public.work_orders;presence public.contractor_presence;event public.contractor_presence_changes;payload jsonb;created uuid;next_state text;next_version integer;previous_status text;
begin
 if caller is null or private.verified_contractor_user() is null then raise exception 'Verified security account required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('check_in','check_out') or p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'Valid presence decision required' using errcode='22023';end if;
 if p_action='check_in' then select * into permit from public.contractor_entry_permits where id=p_permit_id;
 else select * into presence from public.contractor_presence where id=p_presence_id;select * into permit from public.contractor_entry_permits where id=presence.permit_id;end if;
 select * into visit from public.contractor_visits where id=permit.visit_id;
 if visit.id is null or not private.security_property_authorized(visit.property_id) or caller=visit.contractor_user_id then raise exception 'Independent assigned property security required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(visit.organization_id::text,119));
 if not private.security_property_authorized(visit.property_id) then raise exception 'Security authority changed' using errcode='42501';end if;
 payload:=jsonb_build_object('action',p_action,'permit_id',p_permit_id,'presence_id',p_presence_id,'version',p_expected_version,'identity_checked',p_identity_checked,'reason',trim(p_reason));
 select * into event from public.contractor_presence_changes where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then if event.organization_id<>visit.organization_id or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;return jsonb_build_object('id',event.presence_id,'version',event.version,'state',event.new_state);end if;
 select * into offer from public.contractor_work_offers where id=visit.offer_id;
 select * into job from public.work_orders where id=offer.work_order_id for update;
 select * into offer from public.contractor_work_offers where id=visit.offer_id for update;
 select * into visit from public.contractor_visits where id=visit.id for update;
 select * into permit from public.contractor_entry_permits where id=permit.id for update;
 if p_action='check_in' then
 if p_presence_id is not null or p_expected_version is distinct from 0 or p_identity_checked is distinct from true then raise exception 'Confirm identity check before entry' using errcode='22023';end if;
 if permit.state<>'authorized' or permit.valid_from>now() or permit.valid_until<=now() or visit.state<>'confirmed' or visit.starts_at>now() or visit.ends_at<=now() or offer.state<>'accepted' or job.status<>'scheduled' or offer.work_version<>job.revision or not exists(select 1 from public.contractor_accounts c join auth.users u on u.id=c.user_id where c.id=offer.contractor_id and c.is_active and u.email_confirmed_at is not null) then raise exception 'Current in-window authorized scheduled entry required' using errcode='23505';end if;
 insert into public.contractor_presence(organization_id,property_id,visit_id,permit_id,contractor_user_id,state,checked_in_at) values(visit.organization_id,visit.property_id,visit.id,permit.id,visit.contractor_user_id,'on_site',now()) returning id into created;next_state:='on_site';next_version:=1;
 else
 if p_permit_id is not null or p_identity_checked is not null or p_expected_version is null or p_expected_version<1 or p_expected_version>=2147483647 then raise exception 'Check-out response fields only' using errcode='22023';end if;
 select * into presence from public.contractor_presence where id=p_presence_id for update;
 if presence.version<>p_expected_version then raise exception 'Presence changed' using errcode='40001';end if;
 if presence.state<>'on_site' or job.status not in('on_site','in_progress') or offer.work_version<>job.revision then raise exception 'Current on-site work required' using errcode='23505';end if;
 created:=presence.id;next_state:='exited';next_version:=presence.version+1;update public.contractor_presence set state=next_state,checked_out_at=now(),version=next_version where id=presence.id;
 end if;
 previous_status:=job.status;
 update public.work_orders set status=case when p_action='check_in' then 'on_site' else 'in_progress' end,revision=revision+1 where id=job.id;
 update public.contractor_work_offers set work_version=job.revision+1,version=version+1 where id=offer.id;
 insert into public.work_order_changes(work_order_id,organization_id,actor_user_id,request_id,payload,action,previous_status,new_status,previous_priority,new_priority,version,reason) values(job.id,visit.organization_id,caller,p_request_id,jsonb_build_object('presence_id',created),p_action,previous_status,case when p_action='check_in' then 'on_site' else 'in_progress' end,job.priority,job.priority,job.revision+1,trim(p_reason));
 insert into public.contractor_presence_changes(presence_id,organization_id,property_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(created,visit.organization_id,visit.property_id,caller,p_request_id,payload,p_action,presence.state,next_state,next_version,trim(p_reason));
 return jsonb_build_object('id',created,'version',next_version,'state',next_state);
end $$;
revoke all on function private.record_contractor_presence(uuid,text,uuid,uuid,integer,boolean,text) from public,anon,authenticated;
grant execute on function private.record_contractor_presence(uuid,text,uuid,uuid,integer,boolean,text) to authenticated;
create function public.record_contractor_presence(p_request_id uuid,p_action text,p_permit_id uuid,p_presence_id uuid,p_expected_version integer,p_identity_checked boolean,p_reason text) returns jsonb language sql security invoker set search_path='' as $$select private.record_contractor_presence(p_request_id,p_action,p_permit_id,p_presence_id,p_expected_version,p_identity_checked,p_reason);$$;
revoke all on function public.record_contractor_presence(uuid,text,uuid,uuid,integer,boolean,text) from public,anon,authenticated;
grant execute on function public.record_contractor_presence(uuid,text,uuid,uuid,integer,boolean,text) to authenticated;
