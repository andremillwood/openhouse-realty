alter table private.notification_outbox add column delivery_state text not null default 'unknown' check(delivery_state in('unknown','sent','delivered','delayed','bounced','complained','failed','suppressed')),add column delivery_event_at timestamptz;
create unique index notification_outbox_provider_idx on private.notification_outbox(provider_id) where provider_id is not null;
create table private.resend_delivery_events (
 event_id text primary key check(event_id ~ '^[A-Za-z0-9_-]{1,200}$'),provider_id uuid not null,event_type text not null check(event_type in('email.sent','email.delivered','email.delivery_delayed','email.bounced','email.complained','email.failed','email.suppressed')),
 occurred_at timestamptz not null,payload_sha256 text not null check(payload_sha256 ~ '^[a-f0-9]{64}$'),received_at timestamptz not null default now(),outbox_id uuid references private.notification_outbox(id)
);
create index resend_delivery_events_provider_idx on private.resend_delivery_events((provider_id::text),occurred_at);
create index resend_delivery_events_unmatched_idx on private.resend_delivery_events((provider_id::text)) where outbox_id is null;
alter table private.resend_delivery_events enable row level security;
revoke all on private.resend_delivery_events from public,anon,authenticated;
grant select,insert,update on private.resend_delivery_events to service_role;
create function public.reconcile_resend_delivery_events() returns integer language plpgsql security invoker set search_path='' as $$
declare job record;summary record;matched integer:=0;
begin
 for job in select o.id,o.provider_id from private.notification_outbox o where o.provider_id is not null and exists(select 1 from private.resend_delivery_events e where e.provider_id::text=o.provider_id and e.outbox_id is null) order by o.id for update of o skip locked limit 100 loop
  -- All verified evidence is retained. Failure/complaint evidence cannot be erased by an older positive event.
  select event_type,occurred_at into summary from private.resend_delivery_events where provider_id::text=job.provider_id order by case event_type when 'email.complained' then 7 when 'email.bounced' then 6 when 'email.suppressed' then 5 when 'email.failed' then 4 when 'email.delivered' then 3 when 'email.delivery_delayed' then 2 else 1 end desc,occurred_at desc,event_id desc limit 1;
  update private.notification_outbox set delivery_state=case summary.event_type when 'email.delivery_delayed' then 'delayed' else replace(summary.event_type,'email.','') end,delivery_event_at=summary.occurred_at where id=job.id;
  update private.resend_delivery_events set outbox_id=job.id where provider_id::text=job.provider_id and outbox_id is null;
  matched:=matched+1;
 end loop;
 return matched;
end $$;
revoke all on function public.reconcile_resend_delivery_events() from public,anon,authenticated;
grant execute on function public.reconcile_resend_delivery_events() to service_role;
create function public.record_resend_delivery_event(p_event_id text,p_provider_id uuid,p_event_type text,p_occurred_at timestamptz,p_payload_sha256 text) returns jsonb language plpgsql security invoker set search_path='' as $$
declare existing private.resend_delivery_events;matched integer;
begin
 if p_event_id is null or p_event_id !~ '^[A-Za-z0-9_-]{1,200}$' or p_provider_id is null or p_event_type is null or p_event_type not in('email.sent','email.delivered','email.delivery_delayed','email.bounced','email.complained','email.failed','email.suppressed') or p_occurred_at is null or p_occurred_at<'2000-01-01'::timestamptz or p_occurred_at>now()+interval '10 minutes' or p_payload_sha256 is null or p_payload_sha256 !~ '^[a-f0-9]{64}$' then raise exception 'Valid verified delivery event required' using errcode='22023';end if;
 insert into private.resend_delivery_events(event_id,provider_id,event_type,occurred_at,payload_sha256) values(p_event_id,p_provider_id,p_event_type,p_occurred_at,p_payload_sha256) on conflict(event_id) do nothing;
 select * into existing from private.resend_delivery_events where event_id=p_event_id;
 if existing.provider_id<>p_provider_id or existing.event_type<>p_event_type or existing.occurred_at<>p_occurred_at or existing.payload_sha256<>p_payload_sha256 then raise exception 'Delivery event identity already used' using errcode='22023';end if;
 matched:=public.reconcile_resend_delivery_events();
 return jsonb_build_object('accepted',true,'matched',matched);
end $$;
revoke all on function public.record_resend_delivery_event(text,uuid,text,timestamptz,text) from public,anon,authenticated;
grant execute on function public.record_resend_delivery_event(text,uuid,text,timestamptz,text) to service_role;

create function private.staff_notification_delivery_monitor(p_state text,p_family text,p_delivery text,p_page integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid:=private.verified_enquiry_staff_organization();result jsonb;
begin
 if auth.uid() is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_state is null or p_state not in('all','pending','processing','sent','failed','superseded') or p_family is null or p_family not in('all','enquiry','viewing','seller','application','cosigner') or p_delivery is null or p_delivery not in('all','unknown','sent','delivered','delayed','bounced','complained','failed','suppressed') or p_page is null or p_page not between 1 and 99999 then raise exception 'Valid monitor filters and page required' using errcode='22023';end if;
 with scoped as materialized (
  select o.id,o.state,o.audience,o.target_title,o.attempts,o.created_at,o.available_at,o.first_attempt_at,o.sent_at,o.last_error,o.delivery_state,o.delivery_event_at,
   case when o.enquiry_id is not null then 'enquiry' when o.viewing_event_id is not null then 'viewing' when o.seller_lead_id is not null then 'seller' when o.application_event_id is not null then 'application' else 'cosigner' end family
  from private.notification_outbox o where o.organization_id=org
 ), filtered as materialized (select * from scoped where (p_state='all' or state=p_state) and (p_family='all' or family=p_family) and (p_delivery='all' or delivery_state=p_delivery)), totals as (
  select count(*) total,greatest(1,ceil(count(*)::numeric/25)::integer) pages from filtered
 ), page_rows as (
  select * from filtered order by created_at desc,id offset (select (least(p_page,pages)-1)*25 from totals) limit 25
 ) select jsonb_build_object('total',t.total,'pages',t.pages,'page',least(p_page,t.pages),'counts',(select coalesce(jsonb_object_agg(state,n),'{}'::jsonb) from(select state,count(*) n from scoped group by state)c),'delivery_counts',(select coalesce(jsonb_object_agg(delivery_state,n),'{}'::jsonb) from(select delivery_state,count(*) n from scoped group by delivery_state)d),'rows',(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) from page_rows r)) into result from totals t;
 return result;
end $$;
revoke all on function private.staff_notification_delivery_monitor(text,text,text,integer) from public,anon;
grant execute on function private.staff_notification_delivery_monitor(text,text,text,integer) to authenticated;
create function public.staff_notification_delivery_monitor(p_state text,p_family text,p_delivery text,p_page integer) returns jsonb language sql stable security invoker set search_path='' as $$select private.staff_notification_delivery_monitor(p_state,p_family,p_delivery,p_page);$$;
revoke all on function public.staff_notification_delivery_monitor(text,text,text,integer) from public,anon;
grant execute on function public.staff_notification_delivery_monitor(text,text,text,integer) to authenticated;
