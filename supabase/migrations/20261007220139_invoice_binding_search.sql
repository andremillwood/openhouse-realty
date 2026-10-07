create function private.search_invoice_bindings(p_kind text,p_term text,p_property_id uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid:=private.verified_invoice_organization();pattern text;rows jsonb;total integer;
begin
 if auth.uid() is null or org is null then raise exception 'Verified invoice access required' using errcode='42501';end if;
 if p_kind is null or p_kind not in('property','work') or p_term is null or length(p_term)>120 or (p_kind='work' and p_property_id is null) or (p_kind='property' and p_property_id is not null) then raise exception 'Invalid dimension search' using errcode='22023';end if;
 pattern:='%'||replace(replace(replace(trim(p_term),E'\\',E'\\\\'),'%',E'\\%'),'_',E'\\_')||'%';
 if p_kind='property' then
  select jsonb_agg(jsonb_build_object('id',id,'label',name) order by name,id),count(*) into rows,total from(select id,name from public.properties where organization_id=org and name ilike pattern order by name,id limit 26) matches;
 else
  if not exists(select 1 from public.properties where id=p_property_id and organization_id=org) then raise exception 'Organization property required' using errcode='42501';end if;
  select jsonb_agg(jsonb_build_object('id',id,'label',title) order by title,id),count(*) into rows,total from(select id,title from public.work_orders where organization_id=org and property_id=p_property_id and title ilike pattern order by title,id limit 26) matches;
 end if;
 return jsonb_build_object('items',coalesce((select jsonb_agg(value order by ordinal) from jsonb_array_elements(coalesce(rows,'[]')) with ordinality as results(value,ordinal) where ordinal<=25),'[]'::jsonb),'more',total>25);
end $$;
revoke all on function private.search_invoice_bindings(text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function private.search_invoice_bindings(text,text,uuid) to authenticated;
create function public.search_invoice_bindings(p_kind text,p_term text,p_property_id uuid default null) returns jsonb language sql security invoker set search_path='' as $$select private.search_invoice_bindings(p_kind,p_term,p_property_id);$$;
revoke all on function public.search_invoice_bindings(text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.search_invoice_bindings(text,text,uuid) to authenticated;
