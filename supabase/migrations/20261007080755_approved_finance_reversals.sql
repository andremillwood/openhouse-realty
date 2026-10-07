create table public.finance_journal_reversals(
 original_journal_id uuid primary key references public.finance_journals(id),reversal_journal_id uuid not null unique references public.finance_journals(id),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,reason text not null,created_at timestamptz not null default statement_timestamp(),unique(actor_user_id,request_id),check(original_journal_id<>reversal_journal_id)
);
create index finance_reversals_org_idx on public.finance_journal_reversals(organization_id,created_at desc);
alter table public.finance_journal_reversals enable row level security;
revoke all on public.finance_journal_reversals from public,anon,authenticated,service_role;
grant select on public.finance_journal_reversals to authenticated,service_role;
create policy "finance read organization reversals" on public.finance_journal_reversals for select to authenticated using(organization_id=(select private.verified_finance_organization()));
create trigger guard_finance_immutable before update or delete on public.finance_journal_reversals for each row execute function private.guard_finance_immutable();
create function private.reverse_finance_journal(p_request_id uuid,p_journal_id uuid,p_reason text,p_approved boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_finance_organization();original public.finance_journals;prior public.finance_journal_reversals;lines jsonb;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified finance authority required' using errcode='42501';end if;
 if p_request_id is null or p_journal_id is null or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Approved reversal reason required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_finance_organization() is distinct from org then raise exception 'Finance authority changed' using errcode='42501';end if;
 select * into prior from public.finance_journal_reversals where actor_user_id=caller and request_id=p_request_id;
 if prior.original_journal_id is not null then
  if prior.organization_id<>org or prior.original_journal_id<>p_journal_id or prior.reason<>trim(p_reason) then raise exception 'Request ID already used' using errcode='22023';end if;return prior.reversal_journal_id;
 end if;
 select * into original from public.finance_journals where id=p_journal_id and organization_id=org;
 if original.id is null then raise exception 'Organization journal required' using errcode='42501';end if;
 if exists(select 1 from public.finance_journal_reversals where original_journal_id=original.id or reversal_journal_id=original.id) then raise exception 'Journal already reversed or is a reversal' using errcode='23505';end if;
 if exists(select 1 from public.finance_journals where posted_by=caller and request_id=p_request_id) then raise exception 'Request ID already used by posting' using errcode='22023';end if;
 select jsonb_agg(jsonb_build_object('account_id',account_id,'property_id',property_id,'unit_id',unit_id,'debit_minor',credit_minor,'credit_minor',debit_minor) order by line_number) into lines from public.finance_journal_lines where journal_id=original.id and organization_id=org;
 created:=private.post_finance_journal(p_request_id,'JMD','Reversal of journal '||original.id::text,trim(p_reason),true,lines);
 insert into public.finance_journal_reversals(original_journal_id,reversal_journal_id,organization_id,actor_user_id,request_id,reason) values(original.id,created,org,caller,p_request_id,trim(p_reason));
 return created;
end $$;
revoke all on function private.reverse_finance_journal(uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.reverse_finance_journal(uuid,uuid,text,boolean) to authenticated;
create function public.reverse_finance_journal(p_request_id uuid,p_journal_id uuid,p_reason text,p_approved boolean) returns uuid language sql security invoker set search_path='' as $$select private.reverse_finance_journal(p_request_id,p_journal_id,p_reason,p_approved);$$;
revoke all on function public.reverse_finance_journal(uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.reverse_finance_journal(uuid,uuid,text,boolean) to authenticated;
