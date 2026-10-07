create table public.contractor_work_offers(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),work_order_id uuid not null references public.work_orders(id),
 contractor_id uuid not null references public.contractor_accounts(id),company_name_snapshot text not null,job_title text not null,scope_summary text not null,trade text not null,
 work_version integer not null,version integer not null default 1,state text not null check(state in('offered','accepted','declined','withdrawn','expired')),
 expires_at timestamptz not null,created_at timestamptz not null default now()
);
create unique index contractor_work_offers_active_idx on public.contractor_work_offers(work_order_id) where state in('offered','accepted');
create index contractor_work_offers_org_idx on public.contractor_work_offers(organization_id,work_order_id,created_at desc,id);
create index contractor_work_offers_contractor_idx on public.contractor_work_offers(contractor_id,created_at desc,id);
alter table public.contractor_work_offers enable row level security;
revoke all on public.contractor_work_offers from public,anon,authenticated;
grant select on public.contractor_work_offers to authenticated;
grant select,insert,update on public.contractor_work_offers to service_role;
create policy "management read organization work offers" on public.contractor_work_offers for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create policy "verified active contractors read their offers" on public.contractor_work_offers for select to authenticated using(exists(select 1 from public.contractor_accounts c where c.id=contractor_id and c.user_id=(select private.verified_contractor_user()) and c.is_active));
create table public.contractor_work_offer_changes(
 id uuid primary key default gen_random_uuid(),offer_id uuid not null references public.contractor_work_offers(id),organization_id uuid not null references public.organizations(id),
 actor_user_id uuid references auth.users(id),request_id uuid not null,payload jsonb not null,action text not null,previous_state text,new_state text not null,version integer not null,
 reason text not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index contractor_work_offer_changes_history_idx on public.contractor_work_offer_changes(organization_id,offer_id,created_at desc,id);
alter table public.contractor_work_offer_changes enable row level security;
revoke all on public.contractor_work_offer_changes from public,anon,authenticated;
grant select on public.contractor_work_offer_changes to authenticated;
grant select,insert on public.contractor_work_offer_changes to service_role;
create policy "management read internal offer audit" on public.contractor_work_offer_changes for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
alter table public.work_order_changes drop constraint work_order_changes_action_check;
alter table public.work_order_changes add constraint work_order_changes_action_check check(action in('create','triage','cancel','assign','unassign'));
create function private.guard_work_offer_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and row(new.organization_id,new.work_order_id,new.contractor_id,new.company_name_snapshot,new.job_title,new.scope_summary,new.trade,new.expires_at) is distinct from row(old.organization_id,old.work_order_id,old.contractor_id,old.company_name_snapshot,old.job_title,old.scope_summary,old.trade,old.expires_at) then raise exception 'Offer identity and approved scope are immutable' using errcode='23505';end if;
 if not exists(select 1 from public.work_orders where id=new.work_order_id and organization_id=new.organization_id) or not exists(select 1 from public.contractor_accounts where id=new.contractor_id and organization_id=new.organization_id) then raise exception 'Organization offer binding required' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_work_offer_binding() from public,anon,authenticated;
create trigger guard_work_offer_binding before insert or update on public.contractor_work_offers for each row execute function private.guard_work_offer_binding();
create function private.retire_changed_work_offers() returns trigger language plpgsql security definer set search_path='' as $$
declare entry public.contractor_work_offers;reason text;
begin
 if tg_table_name='work_orders' then
 if new.revision=old.revision then return new;end if;reason:='Work order changed before acceptance';
 else
 if new.version=old.version then return new;end if;reason:='Contractor registration changed before acceptance';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.organization_id::text,119));
 for entry in select * from public.contractor_work_offers where state='offered' and organization_id=new.organization_id and ((tg_table_name='work_orders' and work_order_id=new.id) or (tg_table_name='contractor_accounts' and contractor_id=new.id)) for update loop
 update public.contractor_work_offers set state='withdrawn',version=version+1 where id=entry.id;
 insert into public.contractor_work_offer_changes(offer_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason)
 values(entry.id,entry.organization_id,auth.uid(),gen_random_uuid(),jsonb_build_object('source',tg_table_name,'source_id',new.id),'source_changed',entry.state,'withdrawn',entry.version+1,reason);
 end loop;return new;
end $$;
revoke all on function private.retire_changed_work_offers() from public,anon,authenticated;
create trigger retire_changed_work_order_offers after update of revision on public.work_orders for each row execute function private.retire_changed_work_offers();
create trigger retire_changed_contractor_offers after update of version on public.contractor_accounts for each row execute function private.retire_changed_work_offers();
create or replace function private.guard_contractor_identity() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if row(new.organization_id,new.user_id) is distinct from row(old.organization_id,old.user_id) then raise exception 'Contractor organization and identity are immutable' using errcode='23505';end if;
 if exists(select 1 from public.contractor_work_offers where contractor_id=old.id and state='accepted' and (not new.is_active or not(trade=any(new.trade_coverage)))) then raise exception 'Withdraw accepted work before deactivating or removing its trade' using errcode='23505';end if;return new;
end $$;
create function private.manage_contractor_work_offer(p_request_id uuid,p_action text,p_offer_id uuid,p_work_order_id uuid,p_contractor_id uuid,p_expected_offer_version integer,p_expected_work_version integer,p_job_title text,p_scope_summary text,p_trade text,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid;manager_org uuid:=private.verified_work_order_organization();offer public.contractor_work_offers;job public.work_orders;contractor public.contractor_accounts;event public.contractor_work_offer_changes;entry public.contractor_work_offers;payload jsonb;created uuid;next_state text;work_action text;previous_work_state text;
begin
 if caller is null or private.verified_contractor_user() is null then raise exception 'Verified account required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('offer','withdraw','accept','decline','release') or p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'Valid offer action and reason required' using errcode='22023';end if;
 if p_action='offer' then org:=manager_org;if org is null then raise exception 'Verified manager required' using errcode='42501';end if;
 else
 select * into offer from public.contractor_work_offers where id=p_offer_id;
 if offer.id is null then raise exception 'Authorized offer required' using errcode='42501';end if;org:=offer.organization_id;
 if p_action='withdraw' then
 if manager_org is distinct from org then raise exception 'Organization manager required' using errcode='42501';end if;
 elsif not exists(select 1 from public.contractor_accounts where id=offer.contractor_id and user_id=caller and is_active) then raise exception 'Active assigned contractor required' using errcode='42501';end if;
 end if;
 payload:=jsonb_build_object('action',p_action,'offer_id',p_offer_id,'work_order_id',p_work_order_id,'contractor_id',p_contractor_id,'offer_version',p_expected_offer_version,'work_version',p_expected_work_version,'job_title',trim(p_job_title),'scope_summary',trim(p_scope_summary),'trade',trim(p_trade),'reason',trim(p_reason),'approved',p_approved);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if p_action in('offer','withdraw') and private.verified_work_order_organization() is distinct from org then raise exception 'Manager authority changed' using errcode='42501';end if;
 select * into event from public.contractor_work_offer_changes where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then
 if event.organization_id<>org or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
 return jsonb_build_object('id',event.offer_id,'version',event.version,'state',event.new_state);
 end if;
 if p_action='offer' then
 if p_offer_id is not null or p_expected_offer_version is distinct from 0 or p_expected_work_version is null or p_expected_work_version<1 or p_contractor_id is null or p_job_title is null or length(trim(p_job_title)) not between 3 and 160 or p_scope_summary is null or length(trim(p_scope_summary)) not between 20 and 3000 or p_trade is null or p_approved is distinct from true then raise exception 'Approved job scope and current work revision required' using errcode='22023';end if;
 select * into job from public.work_orders where id=p_work_order_id and organization_id=org for update;
 if job.id is null then raise exception 'Organization work order required' using errcode='42501';end if;
 if job.revision<>p_expected_work_version then raise exception 'Work order changed' using errcode='40001';end if;
 if job.status<>'triaged' then raise exception 'Triaged work order required' using errcode='23505';end if;
 select * into contractor from public.contractor_accounts where id=p_contractor_id and organization_id=org and is_active for share;
 if contractor.id is null or not(trim(p_trade)=any(contractor.trade_coverage)) or not exists(select 1 from auth.users where id=contractor.user_id and email_confirmed_at is not null) then raise exception 'Verified active contractor with approved trade required' using errcode='42501';end if;
 for entry in select * from public.contractor_work_offers where work_order_id=job.id and state='offered' and expires_at<=now() for update loop
 update public.contractor_work_offers set state='expired',version=version+1 where id=entry.id;
 insert into public.contractor_work_offer_changes(offer_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(entry.id,org,caller,gen_random_uuid(),jsonb_build_object('expired_offer',entry.id),'expired','offered','expired',entry.version+1,'Unaccepted offer expired');
 end loop;
 insert into public.contractor_work_offers(organization_id,work_order_id,contractor_id,company_name_snapshot,job_title,scope_summary,trade,work_version,version,state,expires_at)
 values(org,job.id,contractor.id,contractor.company_name,trim(p_job_title),trim(p_scope_summary),trim(p_trade),job.revision,1,'offered',now()+interval '7 days') returning id into created;
 next_state:='offered';
 else
 if p_work_order_id is not null or p_contractor_id is not null or p_expected_work_version is not null or p_job_title is not null or p_scope_summary is not null or p_trade is not null or p_approved is not null or p_expected_offer_version is null or p_expected_offer_version<1 then raise exception 'Offer response fields only' using errcode='22023';end if;
 select * into job from public.work_orders where id=offer.work_order_id for update;
 select * into offer from public.contractor_work_offers where id=p_offer_id for update;
 select * into contractor from public.contractor_accounts where id=offer.contractor_id for share;
 if p_action not in('withdraw') and (contractor.user_id<>caller or not contractor.is_active or private.verified_contractor_user() is null) then raise exception 'Current contractor authority required' using errcode='42501';end if;
 if offer.version<>p_expected_offer_version then raise exception 'Offer changed; refresh' using errcode='40001';end if;
 if offer.state='offered' and offer.expires_at<=now() then next_state:='expired';
 elsif p_action in('accept','decline') then
 if offer.state<>'offered' or job.status<>'triaged' or job.revision<>offer.work_version then raise exception 'Current open offer required' using errcode='23505';end if;
 next_state:=case when p_action='accept' then 'accepted' else 'declined' end;
 if p_action='accept' then work_action:='assign';end if;
 else
 if offer.state not in('offered','accepted') or (p_action='release' and offer.state<>'accepted') then raise exception 'Current accepted or pending offer required' using errcode='23505';end if;
 next_state:='withdrawn';
 if offer.state='accepted' then
 if job.status<>'assigned' or job.revision<>offer.work_version then raise exception 'Resolve scheduled or progressed work before withdrawal' using errcode='23505';end if;work_action:='unassign';
 end if;
 end if;
 created:=offer.id;
 end if;
 if p_action<>'offer' then
 update public.contractor_work_offers set state=next_state,version=version+1,work_version=case when work_action is not null then job.revision+1 else work_version end where id=offer.id;
 end if;
 if work_action is not null then
 previous_work_state:=job.status;
 update public.work_orders set status=case when work_action='assign' then 'assigned' else 'triaged' end,assigned_vendor_name=case when work_action='assign' then offer.company_name_snapshot else null end,revision=revision+1 where id=job.id;
 insert into public.work_order_changes(work_order_id,organization_id,actor_user_id,request_id,payload,action,previous_status,new_status,previous_priority,new_priority,version,reason)
 values(job.id,org,caller,p_request_id,jsonb_build_object('offer_id',created,'action',work_action),work_action,previous_work_state,case when work_action='assign' then 'assigned' else 'triaged' end,job.priority,job.priority,job.revision+1,trim(p_reason));
 end if;
 insert into public.contractor_work_offer_changes(offer_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason)
 values(created,org,caller,p_request_id,payload,case when next_state='expired' then 'expired' else p_action end,offer.state,next_state,p_expected_offer_version+1,trim(p_reason));
 return jsonb_build_object('id',created,'version',p_expected_offer_version+1,'state',next_state);
end $$;
revoke all on function private.manage_contractor_work_offer(uuid,text,uuid,uuid,uuid,integer,integer,text,text,text,text,boolean) from public,anon,authenticated;
grant execute on function private.manage_contractor_work_offer(uuid,text,uuid,uuid,uuid,integer,integer,text,text,text,text,boolean) to authenticated;
create function public.manage_contractor_work_offer(p_request_id uuid,p_action text,p_offer_id uuid,p_work_order_id uuid,p_contractor_id uuid,p_expected_offer_version integer,p_expected_work_version integer,p_job_title text,p_scope_summary text,p_trade text,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.manage_contractor_work_offer(p_request_id,p_action,p_offer_id,p_work_order_id,p_contractor_id,p_expected_offer_version,p_expected_work_version,p_job_title,p_scope_summary,p_trade,p_reason,p_approved);$$;
revoke all on function public.manage_contractor_work_offer(uuid,text,uuid,uuid,uuid,integer,integer,text,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.manage_contractor_work_offer(uuid,text,uuid,uuid,uuid,integer,integer,text,text,text,text,boolean) to authenticated;
