create function private.finance_trial_balance(p_through date,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid:=private.verified_finance_organization();cutoff timestamptz;total bigint;pages bigint;page bigint;debit numeric;credit numeric;rows jsonb;
begin
 if auth.uid() is null or org is null then raise exception 'Verified finance access required' using errcode='42501';end if;
 if p_through is null or p_page is null or p_page not between 1 and 100000 then raise exception 'Through date and valid page required' using errcode='22023';end if;
 cutoff:=(p_through+1)::timestamp at time zone 'America/Jamaica';
 select count(*) into total from public.finance_accounts where organization_id=org;
 pages:=greatest(1,(total+24)/25);page:=least(p_page,pages);
 with balances as(
 select a.id,coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric) filter(where j.id is not null),0) as net from public.finance_accounts a left join public.finance_journal_lines l on l.account_id=a.id and l.organization_id=org left join public.finance_journals j on j.id=l.journal_id and j.organization_id=org and j.posted_at<cutoff where a.organization_id=org group by a.id)
 select coalesce(sum(greatest(net,0)),0),coalesce(sum(greatest(-net,0)),0) into debit,credit from balances;
 with balances as(
 select a.id,a.code,a.name,a.account_class,coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric) filter(where j.id is not null),0) as net from public.finance_accounts a left join public.finance_journal_lines l on l.account_id=a.id and l.organization_id=org left join public.finance_journals j on j.id=l.journal_id and j.organization_id=org and j.posted_at<cutoff where a.organization_id=org group by a.id order by a.code,a.id offset (page-1)*25 limit 25)
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'code',code,'name',name,'class',account_class,'debit_minor',greatest(net,0)::text,'credit_minor',greatest(-net,0)::text) order by code,id),'[]'::jsonb) into rows from balances;
 return jsonb_build_object('through',p_through,'currency','JMD','debit_minor',debit::text,'credit_minor',credit::text,'balanced',debit=credit,'accounts',rows,'total',total,'page',page,'pages',pages,'as_of',statement_timestamp());
end $$;
revoke all on function private.finance_trial_balance(date,integer) from public,anon,authenticated,service_role;
grant execute on function private.finance_trial_balance(date,integer) to authenticated;
create function public.finance_trial_balance(p_through date,p_page integer default 1) returns jsonb language sql stable security invoker set search_path='' as $$select private.finance_trial_balance(p_through,p_page);$$;
revoke all on function public.finance_trial_balance(date,integer) from public,anon,authenticated,service_role;
grant execute on function public.finance_trial_balance(date,integer) to authenticated;
