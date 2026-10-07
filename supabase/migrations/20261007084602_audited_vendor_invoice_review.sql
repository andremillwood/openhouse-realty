-- Approved operational invoices do not post to the ledger or execute payments.
create function private.verified_invoice_organization() returns uuid language sql stable security definer set search_path='' as $$
 select s.organization_id from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=auth.uid() and s.role in('admin','manager','finance') and u.email_confirmed_at is not null;
$$;
revoke all on function private.verified_invoice_organization() from public,anon,authenticated,service_role;
grant execute on function private.verified_invoice_organization() to authenticated;
create table public.reviewed_vendor_invoices(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 property_id uuid references public.properties(id),work_order_id uuid references public.work_orders(id),
 vendor_name text not null check(length(trim(vendor_name)) between 2 and 160),invoice_number text not null check(length(trim(invoice_number)) between 1 and 80),
 amount_minor bigint not null check(amount_minor between 1 and 99999999999999),currency text not null default 'JMD' check(currency='JMD'),
 state text not null check(state in('submitted','under_review','approved','rejected')),version integer not null check(version>0),
 submitted_by uuid not null references auth.users(id),reviewed_by uuid references auth.users(id),approved_by uuid references auth.users(id),
 submitted_at timestamptz not null default statement_timestamp(),reviewed_at timestamptz,approved_at timestamptz,
 check(work_order_id is null or property_id is not null),check(reviewed_by is null or reviewed_by<>submitted_by),
 check(approved_by is null or (approved_by<>submitted_by and approved_by<>reviewed_by)),check(state<>'approved' or (reviewed_by is not null and approved_by is not null))
);
create unique index reviewed_invoice_duplicate_idx on public.reviewed_vendor_invoices(organization_id,lower(trim(vendor_name)),lower(trim(invoice_number)));
create index reviewed_invoice_queue_idx on public.reviewed_vendor_invoices(organization_id,state,submitted_at desc,id);
alter table public.reviewed_vendor_invoices enable row level security;
revoke all on public.reviewed_vendor_invoices from public,anon,authenticated,service_role;
grant select on public.reviewed_vendor_invoices to authenticated;
create policy "verified invoice staff read own organization" on public.reviewed_vendor_invoices for select to authenticated using(organization_id=(select private.verified_invoice_organization()));
create table public.vendor_invoice_reviews(
 id uuid primary key default gen_random_uuid(),invoice_id uuid not null references public.reviewed_vendor_invoices(id),organization_id uuid not null references public.organizations(id),
 actor_user_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,action text not null,
 previous_state text,new_state text not null,version integer not null,reason text not null check(length(trim(reason)) between 5 and 500),created_at timestamptz not null default statement_timestamp(),unique(actor_user_id,request_id)
);
create index vendor_invoice_reviews_history_idx on public.vendor_invoice_reviews(organization_id,invoice_id,created_at desc,id);
alter table public.vendor_invoice_reviews enable row level security;
revoke all on public.vendor_invoice_reviews from public,anon,authenticated,service_role;
grant select on public.vendor_invoice_reviews to authenticated;
create policy "verified invoice staff read approval history" on public.vendor_invoice_reviews for select to authenticated using(organization_id=(select private.verified_invoice_organization()));
create trigger immutable_vendor_invoice_reviews before update or delete on public.vendor_invoice_reviews for each row execute function private.guard_finance_immutable();
create function private.guard_reviewed_invoice_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='properties' then
  if new.organization_id is distinct from old.organization_id and exists(select 1 from public.reviewed_vendor_invoices where property_id=old.id) then raise exception 'Invoice history protects property organization' using errcode='23505';end if;
 else
  if row(new.organization_id,new.property_id,new.work_order_id,new.vendor_name,new.invoice_number,new.amount_minor,new.currency,new.submitted_by,new.submitted_at) is distinct from row(old.organization_id,old.property_id,old.work_order_id,old.vendor_name,old.invoice_number,old.amount_minor,old.currency,old.submitted_by,old.submitted_at) then raise exception 'Submitted invoice details are immutable' using errcode='23505';end if;
 end if;return new;
end $$;
revoke all on function private.guard_reviewed_invoice_binding() from public,anon,authenticated,service_role;
create trigger guard_reviewed_invoice_binding before update on public.reviewed_vendor_invoices for each row execute function private.guard_reviewed_invoice_binding();
create trigger guard_reviewed_invoice_property before update of organization_id on public.properties for each row execute function private.guard_reviewed_invoice_binding();
create function private.manage_vendor_invoice(p_request_id uuid,p_action text,p_invoice_id uuid,p_expected_version integer,p_property_id uuid,p_work_order_id uuid,p_vendor_name text,p_invoice_number text,p_amount_minor numeric,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_invoice_organization();current_invoice public.reviewed_vendor_invoices;prior public.vendor_invoice_reviews;payload jsonb;created uuid;next_state text;
begin
 if caller is null or org is null then raise exception 'Verified organization invoice staff required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('submit','review','approve','reject') or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Valid invoice action, revision and explicit approval required' using errcode='22023';end if;
 payload:=jsonb_build_object('action',p_action,'invoice_id',p_invoice_id,'version',p_expected_version,'property_id',p_property_id,'work_order_id',p_work_order_id,'vendor_name',trim(p_vendor_name),'invoice_number',trim(p_invoice_number),'amount_minor',p_amount_minor,'reason',trim(p_reason));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_invoice_organization() is distinct from org then raise exception 'Invoice authority changed' using errcode='42501';end if;
 select * into prior from public.vendor_invoice_reviews where actor_user_id=caller and request_id=p_request_id;
 if prior.id is not null then
  if prior.organization_id<>org or prior.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
  return jsonb_build_object('id',prior.invoice_id,'version',prior.version,'state',prior.new_state);
 end if;
 if p_action='submit' then
  if p_invoice_id is not null or p_expected_version<>0 or p_vendor_name is null or length(trim(p_vendor_name)) not between 2 and 160 or p_invoice_number is null or length(trim(p_invoice_number)) not between 1 and 80 or p_amount_minor is null or p_amount_minor not between 1 and 99999999999999 or trunc(p_amount_minor)<>p_amount_minor or (p_work_order_id is not null and p_property_id is null) then raise exception 'Approved invoice identity, exact amount and bindings required' using errcode='22023';end if;
  if p_property_id is not null then
   perform 1 from public.properties where id=p_property_id and organization_id=org for share;
   if not found then raise exception 'Organization property required' using errcode='42501';end if;
  end if;
  if p_work_order_id is not null then
   perform 1 from public.work_orders where id=p_work_order_id and property_id=p_property_id and organization_id=org for share;
   if not found then raise exception 'Organization work order/property binding required' using errcode='42501';end if;
  end if;
  insert into public.reviewed_vendor_invoices(organization_id,property_id,work_order_id,vendor_name,invoice_number,amount_minor,state,version,submitted_by) values(org,p_property_id,p_work_order_id,trim(p_vendor_name),trim(p_invoice_number),p_amount_minor::bigint,'submitted',1,caller) returning id into created;next_state:='submitted';
 else
  if p_invoice_id is null or p_expected_version<1 or p_property_id is not null or p_work_order_id is not null or p_vendor_name is not null or p_invoice_number is not null or p_amount_minor is not null then raise exception 'Current immutable invoice and revision required' using errcode='22023';end if;
  if private.verified_finance_organization() is distinct from org then raise exception 'Verified finance reviewer required' using errcode='42501';end if;
  select * into current_invoice from public.reviewed_vendor_invoices where id=p_invoice_id and organization_id=org for update;
  if current_invoice.id is null then raise exception 'Organization invoice required' using errcode='42501';end if;
  if current_invoice.version<>p_expected_version then raise exception 'Invoice changed; refresh' using errcode='40001';end if;
  if caller=current_invoice.submitted_by then raise exception 'Independent review required' using errcode='42501';end if;
  if p_action='review' and current_invoice.state='submitted' then next_state:='under_review';
  elsif p_action='approve' and current_invoice.state='under_review' then
   if caller=current_invoice.reviewed_by then raise exception 'Independent approval required' using errcode='42501';end if;next_state:='approved';
  elsif p_action='reject' and current_invoice.state in('submitted','under_review') then next_state:='rejected';
  else raise exception 'Invoice transition unavailable' using errcode='23505';end if;
  update public.reviewed_vendor_invoices set state=next_state,version=version+1,
   reviewed_by=case when p_action='review' then caller else reviewed_by end,reviewed_at=case when p_action='review' then statement_timestamp() else reviewed_at end,
   approved_by=case when p_action='approve' then caller else approved_by end,approved_at=case when p_action='approve' then statement_timestamp() else approved_at end where id=current_invoice.id returning id into created;
 end if;
 insert into public.vendor_invoice_reviews(invoice_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(created,org,caller,p_request_id,payload,p_action,current_invoice.state,next_state,p_expected_version+1,trim(p_reason));
 return jsonb_build_object('id',created,'version',p_expected_version+1,'state',next_state);
end $$;
revoke all on function private.manage_vendor_invoice(uuid,text,uuid,integer,uuid,uuid,text,text,numeric,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.manage_vendor_invoice(uuid,text,uuid,integer,uuid,uuid,text,text,numeric,text,boolean) to authenticated;
create function public.manage_vendor_invoice(p_request_id uuid,p_action text,p_invoice_id uuid,p_expected_version integer,p_property_id uuid,p_work_order_id uuid,p_vendor_name text,p_invoice_number text,p_amount_minor numeric,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.manage_vendor_invoice(p_request_id,p_action,p_invoice_id,p_expected_version,p_property_id,p_work_order_id,p_vendor_name,p_invoice_number,p_amount_minor,p_reason,p_approved);$$;
revoke all on function public.manage_vendor_invoice(uuid,text,uuid,integer,uuid,uuid,text,text,numeric,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.manage_vendor_invoice(uuid,text,uuid,integer,uuid,uuid,text,text,numeric,text,boolean) to authenticated;
