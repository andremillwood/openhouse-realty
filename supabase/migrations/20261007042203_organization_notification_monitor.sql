alter table private.notification_outbox add column organization_id uuid references public.organizations(id);
update private.notification_outbox o set organization_id=coalesce(
 (select organization_id from public.enquiries where id=o.enquiry_id),
 (select v.organization_id from public.viewing_events e join public.viewings v on v.id=e.viewing_id where e.id=o.viewing_event_id),
 (select organization_id from public.seller_leads where id=o.seller_lead_id),
 (select a.organization_id from public.rental_application_events e join public.rental_applications a on a.id=e.application_id where e.id=o.application_event_id),
 (select organization_id from public.application_cosigners where id=o.cosigner_id)
);
alter table private.notification_outbox alter column organization_id set not null;
create index notification_outbox_org_created_idx on private.notification_outbox(organization_id,created_at desc,id);
create function private.bind_notification_organization() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 new.organization_id:=coalesce(
  (select organization_id from public.enquiries where id=new.enquiry_id),
  (select v.organization_id from public.viewing_events e join public.viewings v on v.id=e.viewing_id where e.id=new.viewing_event_id),
  (select organization_id from public.seller_leads where id=new.seller_lead_id),
  (select a.organization_id from public.rental_application_events e join public.rental_applications a on a.id=e.application_id where e.id=new.application_event_id),
  (select organization_id from public.application_cosigners where id=new.cosigner_id)
 );
 if new.organization_id is null then raise exception 'Notification organization unavailable' using errcode='22023';end if;
 return new;
end $$;
revoke all on function private.bind_notification_organization() from public,anon,authenticated;
create trigger bind_notification_organization before insert on private.notification_outbox for each row execute function private.bind_notification_organization();
create function private.staff_notification_monitor(p_state text,p_family text,p_page integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid:=private.verified_enquiry_staff_organization();result jsonb;
begin
 if auth.uid() is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_state is null or p_state not in('all','pending','processing','sent','failed','superseded') or p_family is null or p_family not in('all','enquiry','viewing','seller','application','cosigner') or p_page is null or p_page not between 1 and 99999 then raise exception 'Valid monitor filters and page required' using errcode='22023';end if;
 with scoped as materialized (
  select o.id,o.state,o.audience,o.target_title,o.attempts,o.created_at,o.available_at,o.first_attempt_at,o.sent_at,o.last_error,
   case when o.enquiry_id is not null then 'enquiry' when o.viewing_event_id is not null then 'viewing' when o.seller_lead_id is not null then 'seller' when o.application_event_id is not null then 'application' else 'cosigner' end family
  from private.notification_outbox o where o.organization_id=org
 ), filtered as materialized (select * from scoped where (p_state='all' or state=p_state) and (p_family='all' or family=p_family)), totals as (
  select count(*) total,greatest(1,ceil(count(*)::numeric/25)::integer) pages from filtered
 ), page_rows as (
  select * from filtered order by created_at desc,id offset (select (least(p_page,pages)-1)*25 from totals) limit 25
 ) select jsonb_build_object('total',t.total,'pages',t.pages,'page',least(p_page,t.pages),'counts',(select coalesce(jsonb_object_agg(state,n),'{}'::jsonb) from(select state,count(*) n from scoped group by state)c),'rows',(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) from page_rows r)) into result from totals t;
 return result;
end $$;
revoke all on function private.staff_notification_monitor(text,text,integer) from public,anon;
grant execute on function private.staff_notification_monitor(text,text,integer) to authenticated;
create function public.staff_notification_monitor(p_state text,p_family text,p_page integer) returns jsonb language sql stable security invoker set search_path='' as $$select private.staff_notification_monitor(p_state,p_family,p_page);$$;
revoke all on function public.staff_notification_monitor(text,text,integer) from public,anon;
grant execute on function public.staff_notification_monitor(text,text,integer) to authenticated;
