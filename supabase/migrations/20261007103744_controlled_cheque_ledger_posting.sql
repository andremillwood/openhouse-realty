-- Explicit finance approval, not a resident allocation or automatic revenue classification.
create table public.cheque_ledger_postings(
 cheque_id uuid primary key references public.audited_cheque_receipts(id),organization_id uuid not null references public.organizations(id),
 journal_id uuid not null unique references public.finance_journals(id),clearance_event_id uuid not null unique references public.cheque_custody_events(id),
 cleared_version integer not null check(cleared_version>=3),debit_account_id uuid not null references public.finance_accounts(id),credit_account_id uuid not null references public.finance_accounts(id),
 actor_user_id uuid not null references auth.users(id),request_id uuid not null,reason text not null check(length(trim(reason)) between 5 and 500),posted_at timestamptz not null default statement_timestamp(),
 unique(actor_user_id,request_id),check(debit_account_id<>credit_account_id)
);
alter table public.cheque_ledger_postings enable row level security;
revoke all on public.cheque_ledger_postings from public,anon,authenticated,service_role;
grant select on public.cheque_ledger_postings to authenticated,service_role;
create policy "finance reads organization cheque postings" on public.cheque_ledger_postings for select to authenticated using(organization_id=(select private.verified_finance_organization()));
create trigger immutable_cheque_ledger_postings before update or delete on public.cheque_ledger_postings for each row execute function private.guard_finance_immutable();
create function private.guard_cheque_ledger_binding() returns trigger language plpgsql security definer set search_path='' as $$
declare receipt public.audited_cheque_receipts;
begin
 select * into receipt from public.audited_cheque_receipts where id=new.cheque_id and organization_id=new.organization_id;
 if receipt.id is null or receipt.state<>'cleared' or receipt.version<>new.cleared_version or not exists(select 1 from public.cheque_bank_evidence_snapshots s join public.cheque_custody_events e on e.id=s.event_id where s.cheque_id=receipt.id and s.organization_id=receipt.organization_id and s.kind='clearance' and s.event_id=new.clearance_event_id and s.decision_version=new.cleared_version and e.action='confirm_clear') then raise exception 'Current certified clearance required for cheque posting' using errcode='23505';end if;
 if not exists(select 1 from public.finance_journals where id=new.journal_id and organization_id=new.organization_id and posted_by=new.actor_user_id and request_id=new.request_id and reason=new.reason and created_transaction=pg_current_xact_id()) then raise exception 'Current approved journal required' using errcode='23505';end if;
 if (select count(*) from public.finance_journal_lines where journal_id=new.journal_id)<>2 or
 not exists(select 1 from public.finance_journal_lines where journal_id=new.journal_id and account_id=new.debit_account_id and debit_minor=receipt.amount_minor and credit_minor=0 and property_id=receipt.property_id and unit_id is null) or
 not exists(select 1 from public.finance_journal_lines where journal_id=new.journal_id and account_id=new.credit_account_id and credit_minor=receipt.amount_minor and debit_minor=0 and property_id=receipt.property_id and unit_id is null) then raise exception 'Cheque journal must match exact approved amount and property' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.guard_cheque_ledger_binding() from public,anon,authenticated,service_role;
create trigger guard_cheque_ledger_binding before insert on public.cheque_ledger_postings for each row execute function private.guard_cheque_ledger_binding();
create function private.post_cleared_cheque(p_request_id uuid,p_cheque_id uuid,p_expected_version integer,p_debit_account_id uuid,p_credit_account_id uuid,p_reason text,p_approved boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_finance_organization();receipt public.audited_cheque_receipts;prior public.cheque_ledger_postings;clearance uuid;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified finance authority required' using errcode='42501';end if;
 if p_request_id is null or p_cheque_id is null or p_expected_version is null or p_expected_version<3 or p_debit_account_id is null or p_credit_account_id is null or p_debit_account_id=p_credit_account_id or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Explicit approved cheque accounting details required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_finance_organization() is distinct from org then raise exception 'Finance authority changed' using errcode='42501';end if;
 select * into prior from public.cheque_ledger_postings where actor_user_id=caller and request_id=p_request_id;
 if prior.cheque_id is not null then
  if prior.organization_id<>org or prior.cheque_id<>p_cheque_id or prior.cleared_version<>p_expected_version or prior.debit_account_id<>p_debit_account_id or prior.credit_account_id<>p_credit_account_id or prior.reason<>trim(p_reason) then raise exception 'Request ID already used' using errcode='22023';end if;
  return prior.journal_id;
 end if;
 select * into receipt from public.audited_cheque_receipts where id=p_cheque_id and organization_id=org for update;
 if receipt.id is null then raise exception 'Organization cheque required' using errcode='42501';end if;
 if receipt.version<>p_expected_version then raise exception 'Cheque changed; refresh' using errcode='40001';end if;
 if receipt.state<>'cleared' or exists(select 1 from public.cheque_ledger_postings where cheque_id=receipt.id) then raise exception 'Only an unposted cleared cheque can be posted' using errcode='23505';end if;
 select event_id into clearance from public.cheque_bank_evidence_snapshots where cheque_id=receipt.id and organization_id=org and kind='clearance' and decision_version=receipt.version;
 if clearance is null then raise exception 'Certified clearance required' using errcode='23505';end if;
 if not exists(select 1 from public.finance_accounts where id=p_debit_account_id and organization_id=org and account_class='asset') or not exists(select 1 from public.finance_accounts where id=p_credit_account_id and organization_id=org) then raise exception 'Approved organization asset debit and credit account required' using errcode='42501';end if;
 -- Never adopt a generic journal created by a prior request in another workflow.
 if exists(select 1 from public.finance_journals where posted_by=caller and request_id=p_request_id) then raise exception 'Request ID already used by posting' using errcode='22023';end if;
 created:=private.post_finance_journal(p_request_id,'JMD','Cleared cheque '||receipt.id::text,trim(p_reason),true,jsonb_build_array(
 jsonb_build_object('account_id',p_debit_account_id,'property_id',receipt.property_id,'unit_id',null,'debit_minor',receipt.amount_minor,'credit_minor',0),
 jsonb_build_object('account_id',p_credit_account_id,'property_id',receipt.property_id,'unit_id',null,'debit_minor',0,'credit_minor',receipt.amount_minor)));
 insert into public.cheque_ledger_postings(cheque_id,organization_id,journal_id,clearance_event_id,cleared_version,debit_account_id,credit_account_id,actor_user_id,request_id,reason) values(receipt.id,org,created,clearance,receipt.version,p_debit_account_id,p_credit_account_id,caller,p_request_id,trim(p_reason));
 return created;
end $$;
revoke all on function private.post_cleared_cheque(uuid,uuid,integer,uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.post_cleared_cheque(uuid,uuid,integer,uuid,uuid,text,boolean) to authenticated;
create function public.post_cleared_cheque(p_request_id uuid,p_cheque_id uuid,p_expected_version integer,p_debit_account_id uuid,p_credit_account_id uuid,p_reason text,p_approved boolean) returns uuid language sql security invoker set search_path='' as $$select private.post_cleared_cheque(p_request_id,p_cheque_id,p_expected_version,p_debit_account_id,p_credit_account_id,p_reason,p_approved);$$;
revoke all on function public.post_cleared_cheque(uuid,uuid,integer,uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.post_cleared_cheque(uuid,uuid,integer,uuid,uuid,text,boolean) to authenticated;
create function private.reverse_returned_cheque_posting() returns trigger language plpgsql security definer set search_path='' as $$
declare original uuid;
begin
 if new.action='record_return' then
  select journal_id into original from public.cheque_ledger_postings where cheque_id=new.cheque_id and organization_id=new.organization_id;
  if original is not null and not exists(select 1 from public.finance_journal_reversals where original_journal_id=original) then
   -- The approved return and exact reversal share one transaction. Any failure rolls back both.
   perform private.reverse_finance_journal(new.id,original,new.reason,true);
  end if;
 end if;
 return new;
end $$;
revoke all on function private.reverse_returned_cheque_posting() from public,anon,authenticated,service_role;
create trigger reverse_returned_cheque_posting after insert on public.cheque_custody_events for each row execute function private.reverse_returned_cheque_posting();
