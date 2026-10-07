-- Explicit gross-amount accrual. Payment settlement and tax splits remain separate workflows.
create table public.vendor_invoice_ledger_postings(
 invoice_id uuid primary key references public.reviewed_vendor_invoices(id),organization_id uuid not null references public.organizations(id),
 journal_id uuid not null unique references public.finance_journals(id),approval_event_id uuid not null unique references public.vendor_invoice_reviews(id),
 approved_version integer not null check(approved_version>=3),debit_account_id uuid not null references public.finance_accounts(id),credit_account_id uuid not null references public.finance_accounts(id),
 actor_user_id uuid not null references auth.users(id),request_id uuid not null,reason text not null check(length(trim(reason)) between 5 and 500),posted_at timestamptz not null default statement_timestamp(),
 unique(actor_user_id,request_id),check(debit_account_id<>credit_account_id)
);
alter table public.vendor_invoice_ledger_postings enable row level security;
revoke all on public.vendor_invoice_ledger_postings from public,anon,authenticated,service_role;
grant select on public.vendor_invoice_ledger_postings to authenticated,service_role;
create policy "finance reads organization invoice postings" on public.vendor_invoice_ledger_postings for select to authenticated using(organization_id=(select private.verified_finance_organization()));
create trigger immutable_vendor_invoice_ledger_postings before update or delete on public.vendor_invoice_ledger_postings for each row execute function private.guard_finance_immutable();
create function private.guard_invoice_ledger_binding() returns trigger language plpgsql security definer set search_path='' as $$
declare invoice public.reviewed_vendor_invoices;
begin
 select * into invoice from public.reviewed_vendor_invoices where id=new.invoice_id and organization_id=new.organization_id;
 if invoice.id is null or invoice.state<>'approved' or invoice.version<>new.approved_version or not exists(select 1 from public.vendor_invoice_reviews where id=new.approval_event_id and invoice_id=invoice.id and organization_id=invoice.organization_id and action='approve' and new_state='approved' and version=new.approved_version and actor_user_id=invoice.approved_by) then raise exception 'Current independent invoice approval required' using errcode='23505';end if;
 if not exists(select 1 from public.vendor_invoice_review_evidence where invoice_id=invoice.id and organization_id=invoice.organization_id and kind='invoice' and reviewed_version=invoice.version-1) then raise exception 'Frozen invoice source required' using errcode='23505';end if;
 if not exists(select 1 from public.finance_journals where id=new.journal_id and organization_id=new.organization_id and posted_by=new.actor_user_id and request_id=new.request_id and reason=new.reason and created_transaction=pg_current_xact_id()) then raise exception 'Current approved journal required' using errcode='23505';end if;
 if (select count(*) from public.finance_journal_lines where journal_id=new.journal_id)<>2 or
 not exists(select 1 from public.finance_journal_lines where journal_id=new.journal_id and account_id=new.debit_account_id and debit_minor=invoice.amount_minor and credit_minor=0 and property_id is not distinct from invoice.property_id and unit_id is null) or
 not exists(select 1 from public.finance_journal_lines where journal_id=new.journal_id and account_id=new.credit_account_id and credit_minor=invoice.amount_minor and debit_minor=0 and property_id is not distinct from invoice.property_id and unit_id is null) then raise exception 'Invoice journal must match exact approved amount and property' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.guard_invoice_ledger_binding() from public,anon,authenticated,service_role;
create trigger guard_invoice_ledger_binding before insert on public.vendor_invoice_ledger_postings for each row execute function private.guard_invoice_ledger_binding();
create function private.post_approved_vendor_invoice(p_request_id uuid,p_invoice_id uuid,p_expected_version integer,p_debit_account_id uuid,p_credit_account_id uuid,p_reason text,p_approved boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_finance_organization();invoice public.reviewed_vendor_invoices;prior public.vendor_invoice_ledger_postings;approval uuid;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified finance authority required' using errcode='42501';end if;
 if p_request_id is null or p_invoice_id is null or p_expected_version is null or p_expected_version<3 or p_debit_account_id is null or p_credit_account_id is null or p_debit_account_id=p_credit_account_id or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Explicit approved invoice accounting details required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_finance_organization() is distinct from org then raise exception 'Finance authority changed' using errcode='42501';end if;
 select * into prior from public.vendor_invoice_ledger_postings where actor_user_id=caller and request_id=p_request_id;
 if prior.invoice_id is not null then
  if prior.organization_id<>org or prior.invoice_id<>p_invoice_id or prior.approved_version<>p_expected_version or prior.debit_account_id<>p_debit_account_id or prior.credit_account_id<>p_credit_account_id or prior.reason<>trim(p_reason) then raise exception 'Request ID already used' using errcode='22023';end if;
  return prior.journal_id;
 end if;
 select * into invoice from public.reviewed_vendor_invoices where id=p_invoice_id and organization_id=org for update;
 if invoice.id is null then raise exception 'Organization invoice required' using errcode='42501';end if;
 if invoice.version<>p_expected_version then raise exception 'Invoice changed; refresh' using errcode='40001';end if;
 if invoice.state<>'approved' or exists(select 1 from public.vendor_invoice_ledger_postings where invoice_id=invoice.id) then raise exception 'Only an unposted approved invoice can be posted' using errcode='23505';end if;
 select id into approval from public.vendor_invoice_reviews where invoice_id=invoice.id and organization_id=org and action='approve' and new_state='approved' and version=invoice.version and actor_user_id=invoice.approved_by;
 if approval is null then raise exception 'Independent approval audit required' using errcode='23505';end if;
 if not exists(select 1 from public.finance_accounts where id=p_debit_account_id and organization_id=org and account_class in('asset','expense')) or not exists(select 1 from public.finance_accounts where id=p_credit_account_id and organization_id=org and account_class='liability') then raise exception 'Approved organization asset/expense debit and liability credit required' using errcode='42501';end if;
 if exists(select 1 from public.finance_journals where posted_by=caller and request_id=p_request_id) then raise exception 'Request ID already used by posting' using errcode='22023';end if;
 created:=private.post_finance_journal(p_request_id,'JMD','Approved vendor invoice '||invoice.id::text,trim(p_reason),true,jsonb_build_array(
 jsonb_build_object('account_id',p_debit_account_id,'property_id',invoice.property_id,'unit_id',null,'debit_minor',invoice.amount_minor,'credit_minor',0),
 jsonb_build_object('account_id',p_credit_account_id,'property_id',invoice.property_id,'unit_id',null,'debit_minor',0,'credit_minor',invoice.amount_minor)));
 insert into public.vendor_invoice_ledger_postings(invoice_id,organization_id,journal_id,approval_event_id,approved_version,debit_account_id,credit_account_id,actor_user_id,request_id,reason) values(invoice.id,org,created,approval,invoice.version,p_debit_account_id,p_credit_account_id,caller,p_request_id,trim(p_reason));
 return created;
end $$;
revoke all on function private.post_approved_vendor_invoice(uuid,uuid,integer,uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.post_approved_vendor_invoice(uuid,uuid,integer,uuid,uuid,text,boolean) to authenticated;
create function public.post_approved_vendor_invoice(p_request_id uuid,p_invoice_id uuid,p_expected_version integer,p_debit_account_id uuid,p_credit_account_id uuid,p_reason text,p_approved boolean) returns uuid language sql security invoker set search_path='' as $$select private.post_approved_vendor_invoice(p_request_id,p_invoice_id,p_expected_version,p_debit_account_id,p_credit_account_id,p_reason,p_approved);$$;
revoke all on function public.post_approved_vendor_invoice(uuid,uuid,integer,uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.post_approved_vendor_invoice(uuid,uuid,integer,uuid,uuid,text,boolean) to authenticated;
