create function private.open_house_staff_roster(p_event_id uuid,p_state text,p_page integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid:=private.verified_enquiry_staff_organization();event public.open_house_events;total integer;page integer;pages integer;rows jsonb;reserved integer;going integer;cancelled integer;
begin
 if auth.uid() is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_event_id is null or p_state is null or p_state not in('going','cancelled','all') or p_page is null or p_page not between 1 and 100000 then raise exception 'Valid event/state/page required' using errcode='22023';end if;
 select e.* into event from public.open_house_events e join public.open_house_management m on m.event_id=e.id where e.id=p_event_id and m.organization_id=org;
 if event.id is null then raise exception 'Organization event required' using errcode='42501';end if;
 select count(*) into total from public.open_house_rsvps where event_id=event.id and organization_id=org and (p_state='all' or status=p_state);
 pages:=greatest(1,(total+24)/25);page:=least(p_page,pages);
 select coalesce(sum(party_size) filter(where status='going'),0),count(*) filter(where status='going'),count(*) filter(where status='cancelled') into reserved,going,cancelled from public.open_house_rsvps where event_id=event.id and organization_id=org;
 select coalesce(jsonb_agg(to_jsonb(row) order by row.created_at,row.id),'[]'::jsonb) into rows from (
  select r.id,r.party_size,r.status,r.version,r.created_at,case when u.email_confirmed_at is not null then u.email else null end as contact_email from public.open_house_rsvps r join auth.users u on u.id=r.user_id where r.event_id=event.id and r.organization_id=org and (p_state='all' or r.status=p_state) order by r.created_at,r.id limit 25 offset (page-1)*25
 ) row;
 return jsonb_build_object('event',jsonb_build_object('id',event.id,'title',event.title,'starts_at',event.starts_at,'ends_at',event.ends_at,'capacity',event.capacity,'status',event.status),'page',page,'pages',pages,'total',total,'reserved_places',reserved,'going_parties',going,'cancelled_parties',cancelled,'rows',rows);
end $$;
revoke all on function private.open_house_staff_roster(uuid,text,integer) from public,anon;
grant execute on function private.open_house_staff_roster(uuid,text,integer) to authenticated;
create function public.open_house_staff_roster(p_event_id uuid,p_state text,p_page integer) returns jsonb language sql security invoker set search_path='' as $$select private.open_house_staff_roster(p_event_id,p_state,p_page);$$;
revoke all on function public.open_house_staff_roster(uuid,text,integer) from public,anon;
grant execute on function public.open_house_staff_roster(uuid,text,integer) to authenticated;
