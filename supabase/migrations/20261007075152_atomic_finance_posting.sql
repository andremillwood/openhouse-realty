create function private.post_finance_journal(p_request_id uuid,p_currency text,p_memo text,p_reason text,p_approved boolean,p_lines jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_finance_organization();prior public.finance_journals;payload jsonb;normalized jsonb:='[]';item jsonb;account uuid;property uuid;unit uuid;debit numeric;credit numeric;debits numeric:=0;credits numeric:=0;created uuid;ordinal integer:=0;
begin
 if caller is null or org is null then raise exception 'Verified finance authority required' using errcode='42501';end if;
 if p_request_id is null or p_currency is distinct from 'JMD' or p_memo is null or length(trim(p_memo)) not between 5 and 1000 or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Approved journal details required' using errcode='22023';end if;
 if p_lines is null or jsonb_typeof(p_lines)<>'array' then raise exception 'Journal lines required' using errcode='22023';end if;
 if jsonb_array_length(p_lines) not between 2 and 200 then raise exception 'Journal requires two to two hundred lines' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_finance_organization() is distinct from org then raise exception 'Finance authority changed' using errcode='42501';end if;
 for item in select value from jsonb_array_elements(p_lines) loop
  if jsonb_typeof(item) is distinct from 'object' or jsonb_typeof(item->'account_id') is distinct from 'string' or jsonb_typeof(item->'debit_minor') is distinct from 'number' or jsonb_typeof(item->'credit_minor') is distinct from 'number' then raise exception 'Invalid journal line' using errcode='22023';end if;
  account:=(item->>'account_id')::uuid;
  if account is null then raise exception 'Account reference required' using errcode='22023';end if;
  if item ? 'property_id' and jsonb_typeof(item->'property_id') not in('null','string') or item ? 'unit_id' and jsonb_typeof(item->'unit_id') not in('null','string') then raise exception 'Invalid dimension reference' using errcode='22023';end if;
  property:=(item->>'property_id')::uuid;unit:=(item->>'unit_id')::uuid;
  debit:=(item->>'debit_minor')::numeric;credit:=(item->>'credit_minor')::numeric;
  if debit<>trunc(debit) or credit<>trunc(credit) or debit not between 0 and 99999999999999 or credit not between 0 and 99999999999999 or (debit>0)=(credit>0) or (unit is not null and property is null) then raise exception 'Invalid whole minor-unit amounts or dimensions' using errcode='22023';end if;
  normalized:=normalized||jsonb_build_array(jsonb_build_object('account_id',account,'property_id',property,'unit_id',unit,'debit_minor',debit::bigint,'credit_minor',credit::bigint));
  debits:=debits+debit;credits:=credits+credit;
 end loop;
 if debits<>credits or debits<=0 then raise exception 'Journal is not balanced' using errcode='22023';end if;
 payload:=jsonb_build_object('currency','JMD','memo',trim(p_memo),'reason',trim(p_reason),'approved',true,'lines',normalized);
 select * into prior from public.finance_journals where posted_by=caller and request_id=p_request_id;
 if prior.id is not null then if prior.organization_id<>org or prior.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;return prior.id;end if;
 for item in select value from jsonb_array_elements(normalized) loop
  account:=(item->>'account_id')::uuid;property:=(item->>'property_id')::uuid;unit:=(item->>'unit_id')::uuid;
  if not exists(select 1 from public.finance_accounts where id=account and organization_id=org) then raise exception 'Approved organization account required' using errcode='42501';end if;
  if property is not null then perform 1 from public.properties where id=property and organization_id=org for share;if not found then raise exception 'Organization property required' using errcode='42501';end if;end if;
  if unit is not null then perform 1 from public.units where id=unit and property_id=property for share;if not found then raise exception 'Unit/property binding required' using errcode='42501';end if;end if;
 end loop;
 insert into public.finance_journals(organization_id,request_id,posted_by,currency,memo,reason,payload) values(org,p_request_id,caller,'JMD',trim(p_memo),trim(p_reason),payload) returning id into created;
 for item in select value from jsonb_array_elements(normalized) loop
  ordinal:=ordinal+1;
  insert into public.finance_journal_lines(journal_id,organization_id,line_number,account_id,property_id,unit_id,debit_minor,credit_minor) values(created,org,ordinal,(item->>'account_id')::uuid,(item->>'property_id')::uuid,(item->>'unit_id')::uuid,(item->>'debit_minor')::bigint,(item->>'credit_minor')::bigint);
 end loop;
 return created;
end $$;
revoke all on function private.post_finance_journal(uuid,text,text,text,boolean,jsonb) from public,anon,authenticated,service_role;
grant execute on function private.post_finance_journal(uuid,text,text,text,boolean,jsonb) to authenticated;
create function public.post_finance_journal(p_request_id uuid,p_currency text,p_memo text,p_reason text,p_approved boolean,p_lines jsonb) returns uuid language sql security invoker set search_path='' as $$select private.post_finance_journal(p_request_id,p_currency,p_memo,p_reason,p_approved,p_lines);$$;
revoke all on function public.post_finance_journal(uuid,text,text,text,boolean,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.post_finance_journal(uuid,text,text,text,boolean,jsonb) to authenticated;
