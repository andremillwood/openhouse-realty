alter table public.work_orders add column organization_id uuid references public.organizations(id),add column reported_by uuid references auth.users(id),add column revision integer not null default 0 check(revision>=0);
update public.work_orders w set organization_id=p.organization_id from public.properties p where p.id=w.property_id;
alter table public.work_orders alter column organization_id set not null;
create index work_orders_org_queue_idx on public.work_orders(organization_id,status,created_at desc,id);
create function private.verified_work_order_organization() returns uuid language sql stable security definer set search_path='' as $$
 select s.organization_id from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=auth.uid() and u.email_confirmed_at is not null and s.role in('admin','manager');
$$;
revoke all on function private.verified_work_order_organization() from public,anon,authenticated;
grant execute on function private.verified_work_order_organization() to authenticated;
revoke all on public.work_orders from public,anon,authenticated;
grant select on public.work_orders to authenticated;
grant select,insert,update on public.work_orders to service_role;
create policy "verified managers read organization work orders" on public.work_orders for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create table public.work_order_changes(
 id uuid primary key default gen_random_uuid(),work_order_id uuid not null references public.work_orders(id),organization_id uuid not null references public.organizations(id),
 actor_user_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,action text not null check(action in('create','triage','cancel')),
 previous_status text,new_status text not null,previous_priority text,new_priority text not null,version integer not null,reason text not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index work_order_changes_history_idx on public.work_order_changes(organization_id,work_order_id,created_at desc,id);
create index work_order_changes_actor_idx on public.work_order_changes(actor_user_id,created_at);
alter table public.work_order_changes enable row level security;
revoke all on public.work_order_changes from public,anon,authenticated;
grant select on public.work_order_changes to authenticated;
grant select,insert on public.work_order_changes to service_role;
create policy "verified managers read work order audit" on public.work_order_changes for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create function private.guard_work_order_resource() returns trigger language plpgsql security definer set search_path='' as $$
declare org uuid;
begin
 if tg_op='UPDATE' and row(new.organization_id,new.property_id,new.unit_id,new.reported_by) is distinct from row(old.organization_id,old.property_id,old.unit_id,old.reported_by) then raise exception 'Work order resource and reporter are immutable' using errcode='23505';end if;
 select organization_id into org from public.properties where id=new.property_id for share;
 if org is null or org is distinct from new.organization_id or (new.unit_id is not null and not exists(select 1 from public.units where id=new.unit_id and property_id=new.property_id)) then raise exception 'Organization property and unit required' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.guard_work_order_resource() from public,anon,authenticated;
create trigger guard_work_order_resource before insert or update on public.work_orders for each row execute function private.guard_work_order_resource();
create function private.guard_work_order_property_organization() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.organization_id is distinct from old.organization_id and exists(select 1 from public.work_orders where property_id=old.id) then raise exception 'Work order history protects property organization' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_work_order_property_organization() from public,anon,authenticated;
create trigger guard_work_order_property_organization before update of organization_id on public.properties for each row execute function private.guard_work_order_property_organization();
create function private.manage_work_order(p_request_id uuid,p_action text,p_work_order_id uuid,p_expected_version integer,p_property_id uuid,p_unit_id uuid,p_title text,p_description text,p_priority text,p_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_work_order_organization();current_order public.work_orders;event public.work_order_changes;payload jsonb;created uuid;next_status text;next_priority text;
begin
 if caller is null or org is null then raise exception 'Verified manager required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('create','triage','cancel') or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'Valid action revision and reason required' using errcode='22023';end if;
 payload:=jsonb_build_object('action',p_action,'work_order_id',p_work_order_id,'version',p_expected_version,'property_id',p_property_id,'unit_id',p_unit_id,'title',trim(p_title),'description',trim(p_description),'priority',p_priority,'reason',trim(p_reason));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_work_order_organization() is distinct from org then raise exception 'Manager authority changed' using errcode='42501';end if;
 select * into event from public.work_order_changes where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then
 if event.organization_id<>org or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
 return jsonb_build_object('id',event.work_order_id,'version',event.version,'status',event.new_status);
 end if;
 if p_action='create' then
 if p_work_order_id is not null or p_expected_version<>0 or p_property_id is null or p_title is null or length(trim(p_title)) not between 3 and 160 or p_description is null or length(trim(p_description)) not between 20 and 5000 or p_priority is null or p_priority not in('low','standard','high','urgent') then raise exception 'Property title description and priority required' using errcode='22023';end if;
 perform 1 from public.properties where id=p_property_id and organization_id=org for share;
 if not found then raise exception 'Organization property required' using errcode='42501';end if;
 if p_unit_id is not null then perform 1 from public.units where id=p_unit_id and property_id=p_property_id for share;if not found then raise exception 'Property unit required' using errcode='42501';end if;end if;
 if (select count(*) from public.work_order_changes where actor_user_id=caller and action='create' and created_at>=date_trunc('day',now()))>=30 then raise exception 'Daily work order limit reached' using errcode='23505';end if;
 insert into public.work_orders(property_id,unit_id,organization_id,reported_by,title,description,priority,status,revision)
 values(p_property_id,p_unit_id,org,caller,trim(p_title),trim(p_description),p_priority,'reported',1) returning id into created;
 next_status:='reported';next_priority:=p_priority;
 else
 if p_property_id is not null or p_unit_id is not null or p_title is not null or p_description is not null then raise exception 'Transition fields only' using errcode='22023';end if;
 select * into current_order from public.work_orders where id=p_work_order_id and organization_id=org for update;
 if current_order.id is null then raise exception 'Organization work order required' using errcode='42501';end if;
 if current_order.revision<>p_expected_version then raise exception 'Work order changed; refresh' using errcode='40001';end if;
 if current_order.status not in('reported','triaged') then raise exception 'Work order no longer open for triage' using errcode='23505';end if;
 if p_action='triage' then
 if p_priority is null or p_priority not in('low','standard','high','urgent') then raise exception 'Triage priority required' using errcode='22023';end if;next_status:='triaged';next_priority:=p_priority;
 else
 if p_priority is not null then raise exception 'Cancellation fields only' using errcode='22023';end if;next_status:='cancelled';next_priority:=current_order.priority;
 end if;
 update public.work_orders set status=next_status,priority=next_priority,revision=revision+1 where id=current_order.id returning id into created;
 end if;
 insert into public.work_order_changes(work_order_id,organization_id,actor_user_id,request_id,payload,action,previous_status,new_status,previous_priority,new_priority,version,reason)
 values(created,org,caller,p_request_id,payload,p_action,current_order.status,next_status,current_order.priority,next_priority,p_expected_version+1,trim(p_reason));
 return jsonb_build_object('id',created,'version',p_expected_version+1,'status',next_status);
end $$;
revoke all on function private.manage_work_order(uuid,text,uuid,integer,uuid,uuid,text,text,text,text) from public,anon,authenticated;
grant execute on function private.manage_work_order(uuid,text,uuid,integer,uuid,uuid,text,text,text,text) to authenticated;
create function public.manage_work_order(p_request_id uuid,p_action text,p_work_order_id uuid,p_expected_version integer,p_property_id uuid,p_unit_id uuid,p_title text,p_description text,p_priority text,p_reason text) returns jsonb language sql security invoker set search_path='' as $$select private.manage_work_order(p_request_id,p_action,p_work_order_id,p_expected_version,p_property_id,p_unit_id,p_title,p_description,p_priority,p_reason);$$;
revoke all on function public.manage_work_order(uuid,text,uuid,integer,uuid,uuid,text,text,text,text) from public,anon,authenticated;
grant execute on function public.manage_work_order(uuid,text,uuid,integer,uuid,uuid,text,text,text,text) to authenticated;
