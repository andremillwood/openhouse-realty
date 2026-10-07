create table public.contractor_entry_permits(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),visit_id uuid not null references public.contractor_visits(id),
 contractor_user_id uuid not null references auth.users(id),valid_from timestamptz not null,valid_until timestamptz not null,shared_instructions text not null,
 state text not null check(state in('authorized','revoked')),version integer not null default 1,created_at timestamptz not null default now(),check(valid_until>valid_from)
);
create unique index contractor_entry_permits_active_idx on public.contractor_entry_permits(visit_id) where state='authorized';
create index contractor_entry_permits_org_idx on public.contractor_entry_permits(organization_id,visit_id,created_at desc,id);
create index contractor_entry_permits_user_idx on public.contractor_entry_permits(contractor_user_id,created_at desc,id);
alter table public.contractor_entry_permits enable row level security;
revoke all on public.contractor_entry_permits from public,anon,authenticated;
grant select on public.contractor_entry_permits to authenticated;
grant select,insert,update on public.contractor_entry_permits to service_role;
create policy "management read entry permits" on public.contractor_entry_permits for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create policy "contractor read own entry permits" on public.contractor_entry_permits for select to authenticated using(contractor_user_id=(select private.verified_contractor_user()) and exists(select 1 from public.contractor_visits v join public.contractor_work_offers o on o.id=v.offer_id join public.contractor_accounts c on c.id=o.contractor_id where v.id=visit_id and c.user_id=(select private.verified_contractor_user()) and c.is_active));
create table public.contractor_entry_permit_changes(
 id uuid primary key default gen_random_uuid(),permit_id uuid not null references public.contractor_entry_permits(id),organization_id uuid not null references public.organizations(id),actor_user_id uuid references auth.users(id),request_id uuid not null,payload jsonb not null,
 action text not null,previous_state text,new_state text not null,version integer not null,reason text not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index contractor_entry_permit_changes_history_idx on public.contractor_entry_permit_changes(organization_id,permit_id,created_at desc,id);
alter table public.contractor_entry_permit_changes enable row level security;
revoke all on public.contractor_entry_permit_changes from public,anon,authenticated;
grant select on public.contractor_entry_permit_changes to authenticated;
grant select,insert on public.contractor_entry_permit_changes to service_role;
create policy "management read entry decisions" on public.contractor_entry_permit_changes for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create function private.guard_entry_permit_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and row(new.organization_id,new.visit_id,new.contractor_user_id,new.valid_from,new.valid_until,new.shared_instructions) is distinct from row(old.organization_id,old.visit_id,old.contractor_user_id,old.valid_from,old.valid_until,old.shared_instructions) then raise exception 'Entry authorization scope is immutable' using errcode='23505';end if;
 if not exists(select 1 from public.contractor_visits where id=new.visit_id and organization_id=new.organization_id and contractor_user_id=new.contractor_user_id and starts_at<=new.valid_from and ends_at>=new.valid_until) then raise exception 'Permit must match assigned visit and window' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_entry_permit_binding() from public,anon,authenticated;
create trigger guard_entry_permit_binding before insert or update on public.contractor_entry_permits for each row execute function private.guard_entry_permit_binding();
create function private.revoke_cancelled_visit_permits() returns trigger language plpgsql security definer set search_path='' as $$
declare permit public.contractor_entry_permits;
begin
 if new.state='confirmed' then return new;end if;
 for permit in select * from public.contractor_entry_permits where visit_id=new.id and state='authorized' for update loop
 update public.contractor_entry_permits set state='revoked',version=version+1 where id=permit.id;
 insert into public.contractor_entry_permit_changes(permit_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(permit.id,permit.organization_id,auth.uid(),gen_random_uuid(),jsonb_build_object('visit_id',new.id,'visit_state',new.state),'visit_changed','authorized','revoked',permit.version+1,'Appointment no longer confirmed');
 end loop;return new;
end $$;
revoke all on function private.revoke_cancelled_visit_permits() from public,anon,authenticated;
create trigger revoke_cancelled_visit_permits after update of state on public.contractor_visits for each row execute function private.revoke_cancelled_visit_permits();
create function private.manage_entry_permit(p_request_id uuid,p_action text,p_permit_id uuid,p_visit_id uuid,p_expected_version integer,p_expected_visit_version integer,p_valid_from timestamptz,p_valid_until timestamptz,p_shared_instructions text,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_work_order_organization();permit public.contractor_entry_permits;visit public.contractor_visits;offer public.contractor_work_offers;job public.work_orders;event public.contractor_entry_permit_changes;payload jsonb;created uuid;next_state text;next_version integer;
begin
 if caller is null or org is null then raise exception 'Verified organization manager required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('authorize','revoke') or p_reason is null or length(trim(p_reason)) not between 10 and 500 then raise exception 'Entry decision and authority reason required' using errcode='22023';end if;
 if p_action='authorize' then select * into visit from public.contractor_visits where id=p_visit_id and organization_id=org;
 else select * into permit from public.contractor_entry_permits where id=p_permit_id and organization_id=org;select * into visit from public.contractor_visits where id=permit.visit_id;end if;
 if visit.id is null then raise exception 'Organization appointment required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_work_order_organization() is distinct from org then raise exception 'Manager authority changed' using errcode='42501';end if;
 payload:=jsonb_build_object('action',p_action,'permit_id',p_permit_id,'visit_id',p_visit_id,'version',p_expected_version,'visit_version',p_expected_visit_version,'valid_from',p_valid_from,'valid_until',p_valid_until,'instructions',trim(p_shared_instructions),'reason',trim(p_reason),'approved',p_approved);
 select * into event from public.contractor_entry_permit_changes where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then if event.organization_id<>org or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;return jsonb_build_object('id',event.permit_id,'version',event.version,'state',event.new_state);end if;
 select * into offer from public.contractor_work_offers where id=visit.offer_id;
 select * into job from public.work_orders where id=offer.work_order_id for update;
 select * into offer from public.contractor_work_offers where id=visit.offer_id for update;
 select * into visit from public.contractor_visits where id=visit.id for update;
 if p_action='authorize' then
 if p_permit_id is not null or p_expected_version is distinct from 0 or p_expected_visit_version is null or p_expected_visit_version<1 or p_valid_from is null or p_valid_until is null or not isfinite(p_valid_from) or not isfinite(p_valid_until) or p_valid_from<visit.starts_at or p_valid_until>visit.ends_at or p_valid_until<=p_valid_from or p_valid_until<=now() or p_shared_instructions is null or length(trim(p_shared_instructions)) not between 5 and 1000 or p_approved is distinct from true then raise exception 'Approve entry instructions within the appointment window' using errcode='22023';end if;
 if visit.version<>p_expected_visit_version then raise exception 'Appointment changed' using errcode='40001';end if;
 if visit.state<>'confirmed' or offer.state<>'accepted' or job.status<>'scheduled' or offer.work_version<>job.revision or not exists(select 1 from public.contractor_accounts c join auth.users u on u.id=c.user_id where c.id=offer.contractor_id and c.is_active and u.email_confirmed_at is not null) then raise exception 'Current confirmed scheduled assignment required' using errcode='23505';end if;
 insert into public.contractor_entry_permits(organization_id,visit_id,contractor_user_id,valid_from,valid_until,shared_instructions,state) values(org,visit.id,visit.contractor_user_id,p_valid_from,p_valid_until,trim(p_shared_instructions),'authorized') returning id into created;next_state:='authorized';next_version:=1;
 else
 if p_visit_id is not null or p_expected_visit_version is not null or p_valid_from is not null or p_valid_until is not null or p_shared_instructions is not null or p_approved is not null or p_expected_version is null or p_expected_version<1 or p_expected_version>=2147483647 then raise exception 'Revocation fields only' using errcode='22023';end if;
 select * into permit from public.contractor_entry_permits where id=p_permit_id for update;
 if permit.version<>p_expected_version then raise exception 'Entry permit changed' using errcode='40001';end if;
 if permit.state<>'authorized' then raise exception 'Current authorization required' using errcode='23505';end if;
 created:=permit.id;next_state:='revoked';next_version:=permit.version+1;update public.contractor_entry_permits set state=next_state,version=next_version where id=permit.id;
 end if;
 insert into public.contractor_entry_permit_changes(permit_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(created,org,caller,p_request_id,payload,p_action,permit.state,next_state,next_version,trim(p_reason));
 return jsonb_build_object('id',created,'version',next_version,'state',next_state);
end $$;
revoke all on function private.manage_entry_permit(uuid,text,uuid,uuid,integer,integer,timestamptz,timestamptz,text,text,boolean) from public,anon,authenticated;
grant execute on function private.manage_entry_permit(uuid,text,uuid,uuid,integer,integer,timestamptz,timestamptz,text,text,boolean) to authenticated;
create function public.manage_entry_permit(p_request_id uuid,p_action text,p_permit_id uuid,p_visit_id uuid,p_expected_version integer,p_expected_visit_version integer,p_valid_from timestamptz,p_valid_until timestamptz,p_shared_instructions text,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.manage_entry_permit(p_request_id,p_action,p_permit_id,p_visit_id,p_expected_version,p_expected_visit_version,p_valid_from,p_valid_until,p_shared_instructions,p_reason,p_approved);$$;
revoke all on function public.manage_entry_permit(uuid,text,uuid,uuid,integer,integer,timestamptz,timestamptz,text,text,boolean) from public,anon,authenticated;
grant execute on function public.manage_entry_permit(uuid,text,uuid,uuid,integer,integer,timestamptz,timestamptz,text,text,boolean) to authenticated;
