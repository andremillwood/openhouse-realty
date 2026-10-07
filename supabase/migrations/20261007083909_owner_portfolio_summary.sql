-- Narrow report: access is approved per property, never from staff/demo role selection.
create function private.owner_portfolio_summary(p_from date,p_to date,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare caller uuid:=private.verified_owner_user();total bigint;pages bigint;page bigint;start_at timestamptz;end_at timestamptz;rows jsonb;
begin
 if caller is null then raise exception 'Verified owner account required' using errcode='42501';end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 or p_page is null or p_page not between 1 and 99999 then raise exception 'Valid date range and page required' using errcode='22023';end if;
 start_at:=p_from::timestamp at time zone 'America/Jamaica';end_at:=(p_to+1)::timestamp at time zone 'America/Jamaica';
 select count(*) into total from public.owner_property_access a join public.properties p on p.id=a.property_id and p.organization_id=a.organization_id where a.user_id=caller and a.is_active;
 pages:=greatest(1,(total+24)/25);page:=least(p_page,pages);
 with eligible as (
 select p.id,p.organization_id,p.name,p.area from public.owner_property_access a join public.properties p on p.id=a.property_id and p.organization_id=a.organization_id where a.user_id=caller and a.is_active order by p.name,p.id offset (page-1)*25 limit 25
 ),summaries as (
 select p.*,
 (select count(*) from public.units u where u.property_id=p.id) units,
 (select count(*) from public.work_orders w where w.property_id=p.id and w.organization_id=p.organization_id and w.status not in('completed','closed','cancelled')) open_work_orders,
 coalesce(f.income,0) income,coalesce(f.expense,0) expense
 from eligible p left join lateral (
 select sum(l.credit_minor::numeric-l.debit_minor::numeric) filter(where a.account_class='income') income,
 sum(l.debit_minor::numeric-l.credit_minor::numeric) filter(where a.account_class='expense') expense
 from public.finance_journal_lines l join public.finance_journals j on j.id=l.journal_id and j.organization_id=p.organization_id join public.finance_accounts a on a.id=l.account_id and a.organization_id=p.organization_id
 where l.property_id=p.id and l.organization_id=p.organization_id and j.posted_at>=start_at and j.posted_at<end_at
 ) f on true
 ) select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'area',area,'managed_units',units,'current_open_work_orders',open_work_orders,'posted_income_minor',income::text,'posted_expense_minor',expense::text,'posted_net_minor',(income-expense)::text,'occupancy',null) order by name,id),'[]'::jsonb) into rows from summaries;
 return jsonb_build_object('from',p_from,'to',p_to,'currency','JMD','properties',rows,'total',total,'page',page,'pages',pages,'as_of',statement_timestamp(),'financial_basis','Property-attributed posted income and expense; not cash receipts or owner distributions','occupancy_available',false);
end $$;
revoke all on function private.owner_portfolio_summary(date,date,integer) from public,anon,authenticated,service_role;
grant execute on function private.owner_portfolio_summary(date,date,integer) to authenticated;
create function public.owner_portfolio_summary(p_from date,p_to date,p_page integer default 1) returns jsonb language sql security invoker set search_path='' as $$select private.owner_portfolio_summary(p_from,p_to,p_page);$$;
revoke all on function public.owner_portfolio_summary(date,date,integer) from public,anon,authenticated,service_role;
grant execute on function public.owner_portfolio_summary(date,date,integer) to authenticated;
