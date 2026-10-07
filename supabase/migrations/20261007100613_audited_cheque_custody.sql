-- Custody foundation. Bank transitions and accounting require the subsequent evidence workflow.
create table public.audited_cheque_receipts(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),property_id uuid not null references public.properties(id),
 payer_name text not null check(length(trim(payer_name)) between 2 and 160),bank_name text not null check(length(trim(bank_name)) between 2 and 160),cheque_reference text not null check(length(trim(cheque_reference)) between 1 and 80),
 amount_minor bigint not null check(amount_minor between 1 and 99999999999999),currency text not null default 'JMD' check(currency='JMD'),
 received_by uuid not null references auth.users(id),received_at timestamptz not null default statement_timestamp(),state text not null default 'received' check(state in('received','cancelled')),version integer not null default 1 check(version>0),cancelled_at timestamptz,
 check((state='cancelled')=(cancelled_at is not null)),check(payer_name !~ '[[:cntrl:]]' and bank_name !~ '[[:cntrl:]]' and cheque_reference !~ '[[:cntrl:]]')
);
create unique index cheque_receipt_reference_idx on public.audited_cheque_receipts(organization_id,lower(trim(bank_name)),lower(trim(payer_name)),lower(trim(cheque_reference)));
create index cheque_receipts_scope_idx on public.audited_cheque_receipts(organization_id,state,received_at desc,id);
alter table public.audited_cheque_receipts enable row level security;
revoke all on public.audited_cheque_receipts from public,anon,authenticated,service_role;
grant select on public.audited_cheque_receipts to authenticated,service_role;
create policy "verified finance reads organization cheque custody" on public.audited_cheque_receipts for select to authenticated using(organization_id=(select private.verified_finance_organization()));
create table public.cheque_custody_events(
 id uuid primary key default gen_random_uuid(),cheque_id uuid not null references public.audited_cheque_receipts(id),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),
 request_id uuid not null,payload jsonb not null,action text not null check(action in('receive','cancel')),previous_state text,new_state text not null,version integer not null,
 reason text not null check(length(trim(reason)) between 5 and 500),created_at timestamptz not null default statement_timestamp(),unique(actor_user_id,request_id)
);
create index cheque_custody_history_idx on public.cheque_custody_events(organization_id,cheque_id,created_at desc,id);
alter table public.cheque_custody_events enable row level security;
revoke all on public.cheque_custody_events from public,anon,authenticated,service_role;
grant select on public.cheque_custody_events to authenticated,service_role;
create policy "verified finance reads organization cheque history" on public.cheque_custody_events for select to authenticated using(organization_id=(select private.verified_finance_organization()));
create trigger immutable_cheque_custody_events before update or delete on public.cheque_custody_events for each row execute function private.guard_finance_immutable();
create function private.guard_cheque_custody() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='properties' then
  if new.organization_id is distinct from old.organization_id and exists(select 1 from public.audited_cheque_receipts where property_id=old.id) then raise exception 'Cheque history protects property organization' using errcode='23505';end if;
 else
  if row(new.organization_id,new.property_id,new.payer_name,new.bank_name,new.cheque_reference,new.amount_minor,new.currency,new.received_by,new.received_at) is distinct from row(old.organization_id,old.property_id,old.payer_name,old.bank_name,old.cheque_reference,old.amount_minor,old.currency,old.received_by,old.received_at) then raise exception 'Cheque receipt identity is immutable' using errcode='23505';end if;
  if old.state<>'received' or new.state<>'cancelled' or new.version<>old.version+1 or new.cancelled_at is null then raise exception 'Cheque custody transition unavailable' using errcode='23505';end if;
 end if;return new;
end $$;
revoke all on function private.guard_cheque_custody() from public,anon,authenticated,service_role;
create trigger guard_cheque_custody before update on public.audited_cheque_receipts for each row execute function private.guard_cheque_custody();
create trigger guard_cheque_property_history before update of organization_id on public.properties for each row execute function private.guard_cheque_custody();
create function private.manage_cheque_custody(p_request_id uuid,p_action text,p_cheque_id uuid,p_expected_version integer,p_property_id uuid,p_payer_name text,p_bank_name text,p_cheque_reference text,p_amount_minor numeric,p_evidence_id uuid,p_bank_reference text,p_reason text,p_approved boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_finance_organization();prior public.cheque_custody_events;receipt public.audited_cheque_receipts;payload jsonb;created uuid;next_state text;next_version integer;
begin
 if caller is null or org is null then raise exception 'Verified finance staff required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('receive','cancel') or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true or p_evidence_id is not null or p_bank_reference is not null then raise exception 'Approved custody action required; bank actions require certified evidence workflow' using errcode='22023';end if;
 payload:=jsonb_build_object('action',p_action,'cheque_id',p_cheque_id,'version',p_expected_version,'property_id',p_property_id,'payer_name',trim(p_payer_name),'bank_name',trim(p_bank_name),'cheque_reference',trim(p_cheque_reference),'amount_minor',p_amount_minor,'reason',trim(p_reason));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_finance_organization() is distinct from org then raise exception 'Finance authority changed' using errcode='42501';end if;
 select * into prior from public.cheque_custody_events where actor_user_id=caller and request_id=p_request_id;
 if prior.id is not null then
  if prior.organization_id<>org or prior.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
  return jsonb_build_object('id',prior.cheque_id,'state',prior.new_state,'version',prior.version);
 end if;
 if p_action='receive' then
  if p_cheque_id is not null or p_expected_version<>0 or p_property_id is null or p_payer_name is null or length(trim(p_payer_name)) not between 2 and 160 or p_bank_name is null or length(trim(p_bank_name)) not between 2 and 160 or p_cheque_reference is null or length(trim(p_cheque_reference)) not between 1 and 80 or p_amount_minor is null or p_amount_minor not between 1 and 99999999999999 or trunc(p_amount_minor)<>p_amount_minor or p_payer_name ~ '[[:cntrl:]]' or p_bank_name ~ '[[:cntrl:]]' or p_cheque_reference ~ '[[:cntrl:]]' then raise exception 'Exact approved cheque receipt details required' using errcode='22023';end if;
  perform 1 from public.properties where id=p_property_id and organization_id=org for share;
  if not found then raise exception 'Organization property required' using errcode='42501';end if;
  insert into public.audited_cheque_receipts(organization_id,property_id,payer_name,bank_name,cheque_reference,amount_minor,received_by) values(org,p_property_id,trim(p_payer_name),trim(p_bank_name),trim(p_cheque_reference),p_amount_minor::bigint,caller) returning id into created;
  next_state:='received';next_version:=1;
 else
  if p_cheque_id is null or p_expected_version<1 or p_property_id is not null or p_payer_name is not null or p_bank_name is not null or p_cheque_reference is not null or p_amount_minor is not null then raise exception 'Current immutable cheque receipt required' using errcode='22023';end if;
  select * into receipt from public.audited_cheque_receipts where id=p_cheque_id and organization_id=org for update;
  if receipt.id is null then raise exception 'Organization cheque receipt required' using errcode='42501';end if;
  if receipt.version<>p_expected_version then raise exception 'Cheque changed; refresh' using errcode='40001';end if;
  if receipt.state<>'received' then raise exception 'Cheque cancellation unavailable' using errcode='23505';end if;
  created:=receipt.id;next_state:='cancelled';next_version:=receipt.version+1;
  update public.audited_cheque_receipts set state=next_state,version=next_version,cancelled_at=statement_timestamp() where id=created;
 end if;
 insert into public.cheque_custody_events(cheque_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(created,org,caller,p_request_id,payload,p_action,receipt.state,next_state,next_version,trim(p_reason));
 return jsonb_build_object('id',created,'state',next_state,'version',next_version);
end $$;
revoke all on function private.manage_cheque_custody(uuid,text,uuid,integer,uuid,text,text,text,numeric,uuid,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.manage_cheque_custody(uuid,text,uuid,integer,uuid,text,text,text,numeric,uuid,text,text,boolean) to authenticated;
create function public.manage_cheque_custody(p_request_id uuid,p_action text,p_cheque_id uuid,p_expected_version integer,p_property_id uuid,p_payer_name text,p_bank_name text,p_cheque_reference text,p_amount_minor numeric,p_evidence_id uuid,p_bank_reference text,p_reason text,p_approved boolean) returns jsonb
language sql security invoker set search_path='' as $$select private.manage_cheque_custody(p_request_id,p_action,p_cheque_id,p_expected_version,p_property_id,p_payer_name,p_bank_name,p_cheque_reference,p_amount_minor,p_evidence_id,p_bank_reference,p_reason,p_approved);$$;
revoke all on function public.manage_cheque_custody(uuid,text,uuid,integer,uuid,text,text,text,numeric,uuid,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.manage_cheque_custody(uuid,text,uuid,integer,uuid,text,text,text,numeric,uuid,text,text,boolean) to authenticated;
