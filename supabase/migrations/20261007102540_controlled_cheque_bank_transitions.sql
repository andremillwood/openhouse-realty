-- Custody only: these recorded bank decisions do not post journals or credit resident balances.
alter table public.audited_cheque_receipts drop constraint audited_cheque_receipts_state_check;
alter table public.audited_cheque_receipts add constraint audited_cheque_receipts_state_check check(state in('received','deposited','cleared','returned','cancelled'));
alter table public.cheque_custody_events drop constraint cheque_custody_events_action_check;
alter table public.cheque_custody_events add constraint cheque_custody_events_action_check check(action in('receive','cancel','record_deposit','confirm_clear','record_return'));
create or replace function private.guard_cheque_custody() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='properties' then
  if new.organization_id is distinct from old.organization_id and exists(select 1 from public.audited_cheque_receipts where property_id=old.id) then raise exception 'Cheque history protects property organization' using errcode='23505';end if;
 else
  if row(new.organization_id,new.property_id,new.payer_name,new.bank_name,new.cheque_reference,new.amount_minor,new.currency,new.received_by,new.received_at) is distinct from row(old.organization_id,old.property_id,old.payer_name,old.bank_name,old.cheque_reference,old.amount_minor,old.currency,old.received_by,old.received_at) then raise exception 'Cheque receipt identity is immutable' using errcode='23505';end if;
  if new.version<>old.version+1 or not ((old.state='received' and new.state in('cancelled','deposited')) or (old.state='deposited' and new.state in('cleared','returned')) or (old.state='cleared' and new.state='returned')) or (new.state='cancelled') is distinct from (new.cancelled_at is not null) then raise exception 'Cheque custody transition unavailable' using errcode='23505';end if;
 end if;return new;
end $$;
-- Organization lock 119 also serializes cheque decisions and membership changes.
create or replace function private.cheque_evidence_mutable(p_cheque_id uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.audited_cheque_receipts i
 join public.staff_accounts s on s.user_id=p_actor and s.organization_id=i.organization_id
 join auth.users u on u.id=s.user_id
 where i.id=p_cheque_id and i.state in('received','deposited','cleared')
 and s.role in('admin','finance') and u.email_confirmed_at is not null);
$$;
create or replace function private.guard_cheque_evidence_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  if not exists(select 1 from public.audited_cheque_receipts i join public.staff_accounts a on a.organization_id=i.organization_id and a.user_id=new.user_id and a.role in('admin','finance') join auth.users u on u.id=a.user_id where i.id=new.cheque_id and i.organization_id=new.organization_id and i.state in('received','deposited','cleared') and u.email_confirmed_at is not null) then raise exception 'Verified finance uploader and organization cheque binding required' using errcode='42501';end if;
 else
  if row(new.cheque_id,new.organization_id,new.user_id,new.request_id,new.kind,new.file_name,new.mime_type,new.declared_size,new.object_path,new.created_at,new.expires_at) is distinct from row(old.cheque_id,old.organization_id,old.user_id,old.request_id,old.kind,old.file_name,old.mime_type,old.declared_size,old.object_path,old.created_at,old.expires_at) then raise exception 'Cheque evidence identity is immutable' using errcode='23505';end if;
 end if;return new;
end $$;
create or replace function private.manage_cheque_custody(p_request_id uuid,p_action text,p_cheque_id uuid,p_expected_version integer,p_property_id uuid,p_payer_name text,p_bank_name text,p_cheque_reference text,p_amount_minor numeric,p_evidence_id uuid,p_bank_reference text,p_reason text,p_approved boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_finance_organization();prior public.cheque_custody_events;receipt public.audited_cheque_receipts;payload jsonb;created uuid;next_state text;next_version integer;doc public.cheque_bank_evidence;event_id uuid;kind text;
begin
 if caller is null or org is null then raise exception 'Verified finance staff required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('receive','cancel','record_deposit','confirm_clear','record_return') or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Approved custody action required' using errcode='22023';end if;
 if p_action in('receive','cancel') then
  if p_evidence_id is not null or p_bank_reference is not null then raise exception 'Receipt and cancellation cannot record bank evidence' using errcode='22023';end if;
 else
  if p_evidence_id is null or p_bank_reference is null or length(trim(p_bank_reference)) not between 3 and 120 or p_bank_reference ~ '[[:cntrl:]]' then raise exception 'Certified evidence and bank reference required' using errcode='22023';end if;
 end if;
 payload:=jsonb_build_object('action',p_action,'cheque_id',p_cheque_id,'version',p_expected_version,'property_id',p_property_id,'payer_name',trim(p_payer_name),'bank_name',trim(p_bank_name),'cheque_reference',trim(p_cheque_reference),'amount_minor',p_amount_minor,'reason',trim(p_reason),'evidence_id',p_evidence_id,'bank_reference',trim(p_bank_reference));
 if p_action in('receive','cancel') then payload:=payload-'evidence_id'-'bank_reference';end if;
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
  if p_action='cancel' then
   if receipt.state<>'received' then raise exception 'Cheque cancellation unavailable' using errcode='23505';end if;
   next_state:='cancelled';
  else
   if p_action='record_deposit' and receipt.state='received' then next_state:='deposited';kind:='deposit';
   elsif p_action='confirm_clear' and receipt.state='deposited' then next_state:='cleared';kind:='clearance';
   elsif p_action='record_return' and receipt.state in('deposited','cleared') then next_state:='returned';kind:='return';
   else raise exception 'Bank action unavailable at current custody stage' using errcode='23505';end if;
   select * into doc from public.cheque_bank_evidence where id=p_evidence_id and cheque_id=receipt.id and organization_id=org for update;
   if doc.id is null or doc.state<>'uploaded' or doc.kind<>kind or doc.sha256 is null or doc.actual_size is null or doc.purged_at is not null then raise exception 'Certified matching bank document required' using errcode='23505';end if;
   if exists(select 1 from public.cheque_bank_evidence_snapshots where evidence_id=doc.id) then raise exception 'Bank document already used' using errcode='23505';end if;
   if exists(select 1 from public.cheque_bank_evidence where cheque_id=receipt.id and state='reserved' and expires_at>statement_timestamp()) then raise exception 'Finish or withdraw pending uploads before bank decision' using errcode='23505';end if;
  end if;
  created:=receipt.id;next_version:=receipt.version+1;
  update public.audited_cheque_receipts set state=next_state,version=next_version,cancelled_at=case when next_state='cancelled' then statement_timestamp() else null end where id=created;
 end if;
 insert into public.cheque_custody_events(cheque_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(created,org,caller,p_request_id,payload,p_action,receipt.state,next_state,next_version,trim(p_reason)) returning id into event_id;
 if doc.id is not null then
  insert into public.cheque_bank_evidence_snapshots(event_id,cheque_id,evidence_id,organization_id,decision_version,kind,file_name,mime_type,sha256,actual_size,bank_reference) values(event_id,created,doc.id,org,next_version,doc.kind,doc.file_name,doc.mime_type,doc.sha256,doc.actual_size,trim(p_bank_reference));
 end if;
 return jsonb_build_object('id',created,'state',next_state,'version',next_version);
end $$;
