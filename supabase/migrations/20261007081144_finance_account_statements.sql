create function private.finance_account_statement(p_account_id uuid,p_from date,p_to date,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid:=private.verified_finance_organization();account public.finance_accounts;start_at timestamptz;end_at timestamptz;opening numeric;debits numeric;credits numeric;total bigint;pages bigint;page bigint;entries jsonb;
begin
 if auth.uid() is null or org is null then raise exception 'Verified finance access required' using errcode='42501';end if;
 if p_account_id is null or p_from is null or p_to is null or p_from>p_to or p_to-p_from>366 or p_page is null or p_page not between 1 and 100000 then raise exception 'Account, dates within 367 days and valid page required' using errcode='22023';end if;
 select * into account from public.finance_accounts where id=p_account_id and organization_id=org;
 if account.id is null then raise exception 'Organization account required' using errcode='42501';end if;
 start_at:=p_from::timestamp at time zone 'America/Jamaica';end_at:=(p_to+1)::timestamp at time zone 'America/Jamaica';
 select coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric),0) into opening from public.finance_journal_lines l join public.finance_journals j on j.id=l.journal_id and j.organization_id=org where l.account_id=account.id and l.organization_id=org and j.posted_at<start_at;
 select count(*),coalesce(sum(l.debit_minor),0),coalesce(sum(l.credit_minor),0) into total,debits,credits from public.finance_journal_lines l join public.finance_journals j on j.id=l.journal_id and j.organization_id=org where l.account_id=account.id and l.organization_id=org and j.posted_at>=start_at and j.posted_at<end_at;
 pages:=greatest(1,(total+24)/25);page:=least(p_page,pages);
 select coalesce(jsonb_agg(jsonb_build_object('line_id',id,'journal_id',journal_id,'posted_at',posted_at,'memo',memo,'debit_minor',debit_minor::text,'credit_minor',credit_minor::text,'balance_minor',(opening+running)::text) order by posted_at,journal_id,line_number),'[]'::jsonb) into entries from(
 select l.id,l.journal_id,j.posted_at,j.memo,l.line_number,l.debit_minor,l.credit_minor,sum(l.debit_minor::numeric-l.credit_minor::numeric) over(order by j.posted_at,j.id,l.line_number rows unbounded preceding) as running
 from public.finance_journal_lines l join public.finance_journals j on j.id=l.journal_id and j.organization_id=org where l.account_id=account.id and l.organization_id=org and j.posted_at>=start_at and j.posted_at<end_at order by j.posted_at,j.id,l.line_number offset (page-1)*25 limit 25) selected;
 return jsonb_build_object('account',jsonb_build_object('id',account.id,'code',account.code,'name',account.name,'class',account.account_class),'from',p_from,'to',p_to,'currency','JMD','opening_minor',opening::text,'debit_minor',debits::text,'credit_minor',credits::text,'closing_minor',(opening+debits-credits)::text,'total',total,'page',page,'pages',pages,'entries',entries,'as_of',statement_timestamp());
end $$;
revoke all on function private.finance_account_statement(uuid,date,date,integer) from public,anon,authenticated,service_role;
grant execute on function private.finance_account_statement(uuid,date,date,integer) to authenticated;
create function public.finance_account_statement(p_account_id uuid,p_from date,p_to date,p_page integer default 1) returns jsonb language sql stable security invoker set search_path='' as $$select private.finance_account_statement(p_account_id,p_from,p_to,p_page);$$;
revoke all on function public.finance_account_statement(uuid,date,date,integer) from public,anon,authenticated,service_role;
grant execute on function public.finance_account_statement(uuid,date,date,integer) to authenticated;
