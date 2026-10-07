create function private.security_entry_snapshot(p_permit_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();permit public.contractor_entry_permits;visit public.contractor_visits;offer public.contractor_work_offers;job public.work_orders;presence public.contractor_presence;property_name text;entry_allowed boolean;
begin
 if caller is null or private.verified_contractor_user() is null then raise exception 'Verified account required' using errcode='42501';end if;
 select * into permit from public.contractor_entry_permits where id=p_permit_id;
 select * into visit from public.contractor_visits where id=permit.visit_id;
 if visit.id is null or caller=visit.contractor_user_id or not private.security_property_authorized(visit.property_id) then raise exception 'Independent assigned security required' using errcode='42501';end if;
 select * into offer from public.contractor_work_offers where id=visit.offer_id;
 select * into job from public.work_orders where id=offer.work_order_id;
 select * into presence from public.contractor_presence where visit_id=visit.id;
 select name into property_name from public.properties where id=visit.property_id;
 entry_allowed:=presence.id is null and permit.state='authorized' and permit.valid_from<=now() and permit.valid_until>now() and visit.state='confirmed' and visit.starts_at<=now() and visit.ends_at>now() and offer.state='accepted' and job.status='scheduled' and offer.work_version=job.revision and exists(select 1 from public.contractor_accounts c join auth.users u on u.id=c.user_id where c.id=offer.contractor_id and c.is_active and u.email_confirmed_at is not null);
 return jsonb_build_object('permit_id',permit.id,'property_name',property_name,'company_name',offer.company_name_snapshot,'job_title',offer.job_title,'shared_instructions',permit.shared_instructions,'permit_state',permit.state,'valid_from',permit.valid_from,'valid_until',permit.valid_until,'entry_allowed',coalesce(entry_allowed,false),'presence_id',presence.id,'presence_state',presence.state,'presence_version',presence.version,'checked_in_at',presence.checked_in_at,'checked_out_at',presence.checked_out_at);
end $$;
revoke all on function private.security_entry_snapshot(uuid) from public,anon,authenticated;
grant execute on function private.security_entry_snapshot(uuid) to authenticated;
create function public.security_entry_snapshot(p_permit_id uuid) returns jsonb language sql security invoker set search_path='' as $$select private.security_entry_snapshot(p_permit_id);$$;
revoke all on function public.security_entry_snapshot(uuid) from public,anon,authenticated;
grant execute on function public.security_entry_snapshot(uuid) to authenticated;
