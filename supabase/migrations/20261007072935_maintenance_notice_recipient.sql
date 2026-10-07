create function private.maintenance_notice_recipient(p_event uuid) returns text language sql stable security definer set search_path='' as $$
 select u.email from private.maintenance_notification_events n join auth.users u on u.id=n.contractor_user_id where n.id=p_event and n.kind<>'report_submitted' and u.email_confirmed_at is not null and private.maintenance_notice_current(n.id);
$$;
revoke all on function private.maintenance_notice_recipient(uuid) from public,anon,authenticated;
grant execute on function private.maintenance_notice_recipient(uuid) to service_role;
create or replace function public.queue_maintenance_notification(p_event_id uuid,p_subject text,p_text text) returns uuid language plpgsql security invoker set search_path='' as $$
declare n private.maintenance_notification_events;existing uuid;recipient text;path text;
begin
 if p_subject is null or length(p_subject) not between 5 and 180 or p_subject ~ '[\r\n]' or p_text is null or length(p_text) not between 20 and 2000 then raise exception 'Rendered notification content required' using errcode='22023';end if;
 select * into n from private.maintenance_notification_events where id=p_event_id;
 if n.id is null then raise exception 'Maintenance event unavailable' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(n.organization_id::text,119));
 select id into existing from private.notification_outbox where maintenance_event_id=n.id;
 if existing is not null then return existing;end if;
 if not private.maintenance_notice_current(n.id) then return null;end if;
 if n.kind='report_submitted' then path:='/staff/work-orders/'||n.work_order_id||'/completion';
 else recipient:=private.maintenance_notice_recipient(n.id);path:='/account/work-offers/'||n.offer_id;end if;
 insert into private.notification_outbox(maintenance_event_id,audience,target_title,recipient,subject_snapshot,text_snapshot,action_path) values(n.id,case when n.kind='report_submitted' then 'business' else 'contractor' end,'Maintenance update',recipient,p_subject,p_text,path) returning id into existing;
 return existing;
end $$;
revoke all on function public.queue_maintenance_notification(uuid,text,text) from public,anon,authenticated;
grant execute on function public.queue_maintenance_notification(uuid,text,text) to service_role;
