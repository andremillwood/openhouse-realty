create table public.contractor_visits(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),offer_id uuid not null references public.contractor_work_offers(id),
 contractor_user_id uuid not null references auth.users(id),property_id uuid not null references public.properties(id),unit_id uuid references public.units(id),
 starts_at timestamptz not null,ends_at timestamptz not null,shared_note text not null,
 state text not null check(state in('proposed','confirmed','declined','cancelled')),version integer not null default 1,created_at timestamptz not null default now(),
 check(ends_at>starts_at and ends_at<=starts_at+interval '8 hours')
);
create unique index contractor_visits_active_offer_idx on public.contractor_visits(offer_id) where state in('proposed','confirmed');
create index contractor_visits_calendar_idx on public.contractor_visits(contractor_user_id,starts_at,ends_at) where state in('proposed','confirmed');
create index contractor_visits_resource_idx on public.contractor_visits(property_id,starts_at,ends_at) where state in('proposed','confirmed');
create index contractor_visits_history_idx on public.contractor_visits(organization_id,offer_id,created_at desc,id);
alter table public.contractor_visits enable row level security;
revoke all on public.contractor_visits from public,anon,authenticated;
grant select on public.contractor_visits to authenticated;
grant select,insert,update on public.contractor_visits to service_role;
create policy "managers read own visits" on public.contractor_visits for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create policy "contractors read own visits" on public.contractor_visits for select to authenticated using(contractor_user_id=(select private.verified_contractor_user()) and exists(select 1 from public.contractor_work_offers o join public.contractor_accounts c on c.id=o.contractor_id where o.id=offer_id and c.user_id=(select private.verified_contractor_user()) and c.is_active));
create table public.contractor_visit_changes(
 id uuid primary key default gen_random_uuid(),visit_id uuid not null references public.contractor_visits(id),organization_id uuid not null references public.organizations(id),
 actor_user_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,action text not null,previous_state text,new_state text not null,version integer not null,reason text not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index contractor_visit_changes_history_idx on public.contractor_visit_changes(organization_id,visit_id,created_at desc,id);
alter table public.contractor_visit_changes enable row level security;
revoke all on public.contractor_visit_changes from public,anon,authenticated;
grant select on public.contractor_visit_changes to authenticated;
grant select,insert on public.contractor_visit_changes to service_role;
create policy "managers read visit audit" on public.contractor_visit_changes for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
alter table public.work_order_changes drop constraint work_order_changes_action_check;
alter table public.work_order_changes add constraint work_order_changes_action_check check(action in('create','triage','cancel','assign','unassign','schedule','unschedule'));
create function private.guard_contractor_visit_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and row(new.organization_id,new.offer_id,new.contractor_user_id,new.property_id,new.unit_id,new.starts_at,new.ends_at,new.shared_note) is distinct from row(old.organization_id,old.offer_id,old.contractor_user_id,old.property_id,old.unit_id,old.starts_at,old.ends_at,old.shared_note) then raise exception 'Visit binding and approved schedule are immutable' using errcode='23505';end if;
 if not exists(select 1 from public.contractor_work_offers o join public.contractor_accounts c on c.id=o.contractor_id join public.work_orders w on w.id=o.work_order_id where o.id=new.offer_id and o.organization_id=new.organization_id and c.user_id=new.contractor_user_id and w.property_id=new.property_id and w.unit_id is not distinct from new.unit_id) then raise exception 'Visit assignment binding required' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_contractor_visit_binding() from public,anon,authenticated;
create trigger guard_contractor_visit_binding before insert or update on public.contractor_visits for each row execute function private.guard_contractor_visit_binding();
-- Pending appointments must be resolved before withdrawing an accepted assignment.
create function private.guard_offer_visit_state() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.state='accepted' and new.state<>'accepted' and exists(select 1 from public.contractor_visits where offer_id=old.id and state in('proposed','confirmed')) then raise exception 'Cancel active visit before withdrawing assignment' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_offer_visit_state() from public,anon,authenticated;
create trigger guard_offer_visit_state before update of state on public.contractor_work_offers for each row execute function private.guard_offer_visit_state();
create function private.manage_contractor_visit(p_request_id uuid,p_action text,p_visit_id uuid,p_offer_id uuid,p_expected_version integer,p_expected_offer_version integer,p_starts_at timestamptz,p_ends_at timestamptz,p_shared_note text,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid;offer public.contractor_work_offers;contractor public.contractor_accounts;job public.work_orders;visit public.contractor_visits;event public.contractor_visit_changes;payload jsonb;created uuid;next_state text;work_action text;previous_status text;new_version integer;
begin
 if caller is null or private.verified_contractor_user() is null then raise exception 'Verified account required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('propose','confirm','decline','cancel') or p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'Valid visit action and reason required' using errcode='22023';end if;
 if p_action='propose' then select * into offer from public.contractor_work_offers where id=p_offer_id;
 else select * into visit from public.contractor_visits where id=p_visit_id;select * into offer from public.contractor_work_offers where id=visit.offer_id;end if;
 if offer.id is null then raise exception 'Authorized assignment required' using errcode='42501';end if;org:=offer.organization_id;
 select * into contractor from public.contractor_accounts where id=offer.contractor_id;
 select * into job from public.work_orders where id=offer.work_order_id;
 if p_action='propose' and private.verified_work_order_organization() is distinct from org then raise exception 'Verified organization manager required' using errcode='42501';end if;
 if p_action in('confirm','decline') and (contractor.user_id<>caller or not contractor.is_active) then raise exception 'Assigned contractor required' using errcode='42501';end if;
 if p_action='cancel' and private.verified_work_order_organization() is distinct from org and (contractor.user_id<>caller or not contractor.is_active) then raise exception 'Authorized visit participant required' using errcode='42501';end if;
 -- Global identity lock coordinates this contractor's registrations across organizations.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(contractor.user_id::text,210));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(job.property_id::text,211));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 select * into job from public.work_orders where id=offer.work_order_id for update;
 select * into offer from public.contractor_work_offers where id=offer.id for update;
 select * into contractor from public.contractor_accounts where id=offer.contractor_id for share;
 if private.verified_contractor_user() is null then raise exception 'Current verified account required' using errcode='42501';end if;
 if p_action='propose' and private.verified_work_order_organization() is distinct from org then raise exception 'Manager authority changed' using errcode='42501';end if;
 if p_action in('confirm','decline') and (contractor.user_id<>caller or not contractor.is_active) then raise exception 'Contractor authority changed' using errcode='42501';end if;
 if p_action='cancel' and private.verified_work_order_organization() is distinct from org and (contractor.user_id<>caller or not contractor.is_active) then raise exception 'Participant authority changed' using errcode='42501';end if;
 payload:=jsonb_build_object('action',p_action,'visit_id',p_visit_id,'offer_id',p_offer_id,'version',p_expected_version,'offer_version',p_expected_offer_version,'starts_at',p_starts_at,'ends_at',p_ends_at,'shared_note',trim(p_shared_note),'reason',trim(p_reason),'approved',p_approved);
 select * into event from public.contractor_visit_changes where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then if event.organization_id<>org or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;return jsonb_build_object('id',event.visit_id,'version',event.version,'state',event.new_state);end if;
 if p_action='propose' then
 if p_visit_id is not null or p_expected_version is distinct from 0 or p_expected_offer_version is null or p_expected_offer_version<1 or p_starts_at is null or p_ends_at is null or not isfinite(p_starts_at) or not isfinite(p_ends_at) or p_starts_at<=now() or p_starts_at>now()+interval '90 days' or p_ends_at<=p_starts_at or p_ends_at>p_starts_at+interval '8 hours' or p_shared_note is null or length(trim(p_shared_note)) not between 5 and 1000 or p_approved is distinct from true then raise exception 'Approved future visit window required' using errcode='22023';end if;
 if offer.version<>p_expected_offer_version then raise exception 'Assignment changed' using errcode='40001';end if;
 if offer.state<>'accepted' or job.status<>'assigned' or offer.work_version<>job.revision or not contractor.is_active or not exists(select 1 from auth.users where id=contractor.user_id and email_confirmed_at is not null) then raise exception 'Current accepted assignment required' using errcode='23505';end if;
 if exists(select 1 from public.contractor_visits v where v.state in('proposed','confirmed') and v.starts_at<p_ends_at and v.ends_at>p_starts_at and (v.contractor_user_id=contractor.user_id or (v.property_id=job.property_id and (v.unit_id is null or job.unit_id is null or v.unit_id=job.unit_id)))) then raise exception 'Contractor or managed location already reserved' using errcode='23505';end if;
 insert into public.contractor_visits(organization_id,offer_id,contractor_user_id,property_id,unit_id,starts_at,ends_at,shared_note,state) values(org,offer.id,contractor.user_id,job.property_id,job.unit_id,p_starts_at,p_ends_at,trim(p_shared_note),'proposed') returning id into created;next_state:='proposed';new_version:=1;
 else
 if p_offer_id is not null or p_expected_offer_version is not null or p_starts_at is not null or p_ends_at is not null or p_shared_note is not null or p_approved is not null or p_expected_version is null or p_expected_version<1 or p_expected_version>=2147483647 then raise exception 'Visit response fields only' using errcode='22023';end if;
 select * into visit from public.contractor_visits where id=p_visit_id for update;
 if visit.version<>p_expected_version then raise exception 'Visit changed' using errcode='40001';end if;
 if p_action in('confirm','decline') then
 if visit.state<>'proposed' or offer.state<>'accepted' or job.status<>'assigned' or job.revision<>offer.work_version then raise exception 'Current proposed visit required' using errcode='23505';end if;
 if p_action='confirm' and visit.starts_at<=now() then raise exception 'Future appointment required' using errcode='23505';end if;
 next_state:=case when p_action='confirm' then 'confirmed' else 'declined' end;if p_action='confirm' then work_action:='schedule';end if;
 else
 if visit.state not in('proposed','confirmed') then raise exception 'Active visit required' using errcode='23505';end if;next_state:='cancelled';
 if visit.state='confirmed' then if job.status<>'scheduled' or job.revision<>offer.work_version then raise exception 'Resolve progressed work before cancellation' using errcode='23505';end if;work_action:='unschedule';end if;
 end if;
 created:=visit.id;new_version:=visit.version+1;update public.contractor_visits set state=next_state,version=new_version where id=visit.id;
 end if;
 if work_action is not null then
 previous_status:=job.status;
 update public.work_orders set status=case when work_action='schedule' then 'scheduled' else 'assigned' end,scheduled_start=case when work_action='schedule' then visit.starts_at else null end,scheduled_end=case when work_action='schedule' then visit.ends_at else null end,revision=revision+1 where id=job.id;
 update public.contractor_work_offers set work_version=job.revision+1,version=version+1 where id=offer.id;
 insert into public.work_order_changes(work_order_id,organization_id,actor_user_id,request_id,payload,action,previous_status,new_status,previous_priority,new_priority,version,reason) values(job.id,org,caller,p_request_id,jsonb_build_object('visit_id',created),work_action,previous_status,case when work_action='schedule' then 'scheduled' else 'assigned' end,job.priority,job.priority,job.revision+1,trim(p_reason));
 end if;
 insert into public.contractor_visit_changes(visit_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(created,org,caller,p_request_id,payload,p_action,visit.state,next_state,new_version,trim(p_reason));
 return jsonb_build_object('id',created,'version',new_version,'state',next_state);
end $$;
revoke all on function private.manage_contractor_visit(uuid,text,uuid,uuid,integer,integer,timestamptz,timestamptz,text,text,boolean) from public,anon,authenticated;
grant execute on function private.manage_contractor_visit(uuid,text,uuid,uuid,integer,integer,timestamptz,timestamptz,text,text,boolean) to authenticated;
create function public.manage_contractor_visit(p_request_id uuid,p_action text,p_visit_id uuid,p_offer_id uuid,p_expected_version integer,p_expected_offer_version integer,p_starts_at timestamptz,p_ends_at timestamptz,p_shared_note text,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.manage_contractor_visit(p_request_id,p_action,p_visit_id,p_offer_id,p_expected_version,p_expected_offer_version,p_starts_at,p_ends_at,p_shared_note,p_reason,p_approved);$$;
revoke all on function public.manage_contractor_visit(uuid,text,uuid,uuid,integer,integer,timestamptz,timestamptz,text,text,boolean) from public,anon,authenticated;
grant execute on function public.manage_contractor_visit(uuid,text,uuid,uuid,integer,integer,timestamptz,timestamptz,text,text,boolean) to authenticated;
