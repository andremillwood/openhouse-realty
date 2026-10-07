create or replace function private.staff_notification_monitor(p_state text,p_family text,p_page integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid:=private.verified_enquiry_staff_organization();result jsonb;
begin
 if auth.uid() is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_state is null or p_state not in('all','pending','processing','sent','failed','superseded') or p_family is null or p_family not in('all','enquiry','viewing','seller','application','cosigner','open_house','maintenance') or p_page is null or p_page not between 1 and 99999 then raise exception 'Valid monitor filters and page required' using errcode='22023';end if;
 with scoped as materialized (
  select o.id,o.state,o.audience,o.target_title,o.attempts,o.created_at,o.available_at,o.first_attempt_at,o.sent_at,o.last_error,
   case when o.enquiry_id is not null then 'enquiry' when o.viewing_event_id is not null then 'viewing' when o.seller_lead_id is not null then 'seller' when o.application_event_id is not null then 'application' when o.cosigner_id is not null then 'cosigner' when o.open_house_notice_id is not null then 'open_house' else 'maintenance' end family
  from private.notification_outbox o where o.organization_id=org
 ), filtered as materialized (select * from scoped where (p_state='all' or state=p_state) and (p_family='all' or family=p_family)), totals as (
  select count(*) total,greatest(1,ceil(count(*)::numeric/25)::integer) pages from filtered
 ), page_rows as (
  select * from filtered order by created_at desc,id offset (select (least(p_page,pages)-1)*25 from totals) limit 25
 ) select jsonb_build_object('total',t.total,'pages',t.pages,'page',least(p_page,t.pages),'counts',(select coalesce(jsonb_object_agg(state,n),'{}'::jsonb) from(select state,count(*) n from scoped group by state)c),'rows',(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) from page_rows r)) into result from totals t;
 return result;
end $$;

create or replace function private.staff_notification_delivery_monitor(p_state text,p_family text,p_delivery text,p_page integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid:=private.verified_enquiry_staff_organization();result jsonb;
begin
 if auth.uid() is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_state is null or p_state not in('all','pending','processing','sent','failed','superseded') or p_family is null or p_family not in('all','enquiry','viewing','seller','application','cosigner','open_house','maintenance') or p_delivery is null or p_delivery not in('all','unknown','sent','delivered','delayed','bounced','complained','failed','suppressed') or p_page is null or p_page not between 1 and 99999 then raise exception 'Valid monitor filters and page required' using errcode='22023';end if;
 with scoped as materialized (
  select o.id,o.state,o.audience,o.target_title,o.attempts,o.created_at,o.available_at,o.first_attempt_at,o.sent_at,o.last_error,o.delivery_state,o.delivery_event_at,
   case when o.enquiry_id is not null then 'enquiry' when o.viewing_event_id is not null then 'viewing' when o.seller_lead_id is not null then 'seller' when o.application_event_id is not null then 'application' when o.cosigner_id is not null then 'cosigner' when o.open_house_notice_id is not null then 'open_house' else 'maintenance' end family
  from private.notification_outbox o where o.organization_id=org
 ), filtered as materialized (select * from scoped where (p_state='all' or state=p_state) and (p_family='all' or family=p_family) and (p_delivery='all' or delivery_state=p_delivery)), totals as (
  select count(*) total,greatest(1,ceil(count(*)::numeric/25)::integer) pages from filtered
 ), page_rows as (
  select * from filtered order by created_at desc,id offset (select (least(p_page,pages)-1)*25 from totals) limit 25
 ) select jsonb_build_object('total',t.total,'pages',t.pages,'page',least(p_page,t.pages),'counts',(select coalesce(jsonb_object_agg(state,n),'{}'::jsonb) from(select state,count(*) n from scoped group by state)c),'delivery_counts',(select coalesce(jsonb_object_agg(delivery_state,n),'{}'::jsonb) from(select delivery_state,count(*) n from scoped group by delivery_state)d),'rows',(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) from page_rows r)) into result from totals t;
 return result;
end $$;
