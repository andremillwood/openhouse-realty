create function private.search_invoice_work_orders(p_property_id uuid,p_term text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid:=private.verified_finance_organization();pattern text;rows jsonb;total integer;
begin
 if auth.uid() is null or org is null then raise exception 'Verified finance access required' using errcode='42501';end if;
 if p_property_id is null or p_term is null or length(p_term)>120 then raise exception 'Selected property and bounded search required' using errcode='22023';end if;
 if not exists(select 1 from public.properties where id=p_property_id and organization_id=org) then raise exception 'Organization property required' using errcode='42501';end if;
 pattern:='%'||replace(replace(replace(trim(p_term),E'\\',E'\\\\'),'%',E'\\%'),'_',E'\\_')||'%';
 select jsonb_agg(jsonb_build_object('id',id,'label',title) order by title,id),count(*) into rows,total from (select id,title from public.work_orders where property_id=p_property_id and organization_id=org and title ilike pattern order by title,id limit 26) matches;
 return jsonb_build_object('items',coalesce((select jsonb_agg(value order by ordinal) from jsonb_array_elements(coalesce(rows,'[]')) with ordinality as results(value,ordinal) where ordinal<=25),'[]'::jsonb),'more',total>25);
end $$;
revoke all on function private.search_invoice_work_orders(uuid,text) from public,anon,authenticated,service_role;
grant execute on function private.search_invoice_work_orders(uuid,text) to authenticated;
create function public.search_invoice_work_orders(p_property_id uuid,p_term text) returns jsonb language sql stable security invoker set search_path='' as $$select private.search_invoice_work_orders(p_property_id,p_term);$$;
revoke all on function public.search_invoice_work_orders(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.search_invoice_work_orders(uuid,text) to authenticated;
