alter table private.notification_outbox add column maintenance_event_id uuid references private.maintenance_notification_events(id);
alter table private.notification_outbox drop constraint notification_outbox_entity;
alter table private.notification_outbox add constraint notification_outbox_entity check(num_nonnulls(enquiry_id,viewing_event_id,seller_lead_id,application_event_id,cosigner_id,open_house_notice_id,maintenance_event_id)=1);
alter table private.notification_outbox drop constraint notification_outbox_audience_check;
alter table private.notification_outbox add constraint notification_outbox_audience_check check(audience in('business','prospect','contractor'));
create unique index notification_outbox_maintenance_idx on private.notification_outbox(maintenance_event_id) where maintenance_event_id is not null;
create function public.pending_maintenance_notifications() returns table(event_id uuid,kind text,reference uuid) language sql stable security invoker set search_path='' as $$
 select n.id,n.kind,case when n.kind='report_submitted' then n.work_order_id else n.offer_id end from private.maintenance_notification_events n where not exists(select 1 from private.notification_outbox o where o.maintenance_event_id=n.id) and private.maintenance_notice_current(n.id) order by n.created_at,n.id limit 20;
$$;
revoke all on function public.pending_maintenance_notifications() from public,anon,authenticated;
grant execute on function public.pending_maintenance_notifications() to service_role;
create function private.maintenance_outbox_current(p_event uuid,p_recipient text) returns boolean language sql stable security definer set search_path='' as $$
 select private.maintenance_notice_current(p_event) and exists(select 1 from private.maintenance_notification_events n join auth.users u on u.id=n.contractor_user_id where n.id=p_event and (n.kind='report_submitted' or lower(u.email)=lower(p_recipient)));
$$;
revoke all on function private.maintenance_outbox_current(uuid,text) from public,anon,authenticated;
grant execute on function private.maintenance_outbox_current(uuid,text) to service_role;
create function public.queue_maintenance_notification(p_event_id uuid,p_subject text,p_text text) returns uuid language plpgsql security invoker set search_path='' as $$
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
 else select email into recipient from auth.users where id=n.contractor_user_id and email_confirmed_at is not null;path:='/account/work-offers/'||n.offer_id;end if;
 insert into private.notification_outbox(maintenance_event_id,audience,target_title,recipient,subject_snapshot,text_snapshot,action_path) values(n.id,case when n.kind='report_submitted' then 'business' else 'contractor' end,'Maintenance update',recipient,p_subject,p_text,path) returning id into existing;
 return existing;
end $$;
revoke all on function public.queue_maintenance_notification(uuid,text,text) from public,anon,authenticated;
grant execute on function public.queue_maintenance_notification(uuid,text,text) to service_role;
create or replace function private.bind_notification_organization() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 new.organization_id:=coalesce((select organization_id from public.enquiries where id=new.enquiry_id),(select v.organization_id from public.viewing_events e join public.viewings v on v.id=e.viewing_id where e.id=new.viewing_event_id),(select organization_id from public.seller_leads where id=new.seller_lead_id),(select a.organization_id from public.rental_application_events e join public.rental_applications a on a.id=e.application_id where e.id=new.application_event_id),(select organization_id from public.application_cosigners where id=new.cosigner_id),(select organization_id from private.open_house_notices where id=new.open_house_notice_id),(select organization_id from private.maintenance_notification_events where id=new.maintenance_event_id));
 if new.organization_id is null then raise exception 'Notification organization unavailable' using errcode='22023';end if;return new;
end $$;
create or replace function public.claim_enquiry_notifications(p_sender text,p_recipient text) returns table(outbox_id uuid,enquiry_id uuid,lease_token uuid,contact_name text,contact_email text,phone text,message text,target_title text,sender text,recipient text,subject_snapshot text,text_snapshot text)
language plpgsql security invoker set search_path='' as $$
begin
 update private.notification_outbox o set state='superseded',last_error='Maintenance notice no longer current',lease_token=null,lease_expires_at=null where o.maintenance_event_id is not null and o.state in('pending','processing') and not private.maintenance_outbox_current(o.maintenance_event_id,o.recipient);
 update private.notification_outbox o set state='superseded',last_error='Open house notice expired or changed',lease_token=null,lease_expires_at=null where o.open_house_notice_id is not null and o.state in('pending','processing') and not private.open_house_notice_current(o.open_house_notice_id);
 if p_sender is null or p_recipient is null or length(p_sender) not between 3 and 320 or length(p_recipient) not between 3 and 254 or p_sender ~ '[\r\n]' or p_recipient ~ '[\r\n]' then raise exception 'Invalid sender configuration' using errcode='22023'; end if;
 update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where state='processing' and attempts>=6 and lease_expires_at<now();
 update private.notification_outbox set state='failed',last_error='Delivery uncertain beyond provider idempotency window; manual review required' where state in('pending','processing') and first_attempt_at<now()-interval '23 hours';
 return query with candidates as (
  select o.id from private.notification_outbox o where o.cosigner_id is null and o.open_house_notice_id is null and o.maintenance_event_id is null and o.attempts<6 and ((o.state='pending' and o.available_at<=now()) or (o.state='processing' and o.lease_expires_at<now())) order by o.created_at for update skip locked limit 5
 ), claimed as (
  update private.notification_outbox o set state='processing',attempts=o.attempts+1,lease_token=gen_random_uuid(),lease_expires_at=now()+interval '5 minutes',first_attempt_at=coalesce(o.first_attempt_at,now()),sender=coalesce(o.sender,p_sender),recipient=coalesce(o.recipient,p_recipient) from candidates c where o.id=c.id returning o.*
 ) select c.id,e.id,c.lease_token,coalesce(e.contact_name,''),coalesce(e.contact_email,''),coalesce(e.phone,''),coalesce(e.message,''),c.target_title,c.sender,c.recipient,c.subject_snapshot,c.text_snapshot from claimed c left join public.enquiries e on e.id=c.enquiry_id;
end $$;
revoke all on function public.claim_enquiry_notifications(text,text) from public,anon,authenticated;
grant execute on function public.claim_enquiry_notifications(text,text) to service_role;

create or replace function public.claim_transactional_notifications(p_sender text,p_recipient text,p_app_origin text) returns table(outbox_id uuid,enquiry_id uuid,lease_token uuid,contact_name text,contact_email text,phone text,message text,target_title text,sender text,recipient text,subject_snapshot text,text_snapshot text)
language plpgsql security invoker set search_path='' as $$
begin
 if p_app_origin is null or length(p_app_origin)>300 or p_app_origin !~ '^https://[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?(:[0-9]{1,5})?$' then raise exception 'Canonical HTTPS application origin required' using errcode='22023';end if;
 update private.notification_outbox o set state='superseded',last_error='Invitation expired or closed',lease_token=null,lease_expires_at=null where o.cosigner_id is not null and o.state in('pending','processing') and not exists(select 1 from public.application_cosigners c join public.rental_applications a on a.id=c.application_id where c.id=o.cosigner_id and c.state='pending' and c.expires_at>now() and a.status in('submitted','under_review','needs_info'));
 update private.notification_outbox o set state='superseded',last_error='Maintenance notice no longer current',lease_token=null,lease_expires_at=null where o.maintenance_event_id is not null and o.state in('pending','processing') and not private.maintenance_outbox_current(o.maintenance_event_id,o.recipient);
 update private.notification_outbox o set state='superseded',last_error='Open house notice expired or changed',lease_token=null,lease_expires_at=null where o.open_house_notice_id is not null and o.state in('pending','processing') and not private.open_house_notice_current(o.open_house_notice_id);
 if p_sender is null or p_recipient is null or length(p_sender) not between 3 and 320 or length(p_recipient) not between 3 and 254 or p_sender ~ '[\r\n]' or p_recipient ~ '[\r\n]' then raise exception 'Invalid sender configuration' using errcode='22023'; end if;
 update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where state='processing' and attempts>=6 and lease_expires_at<now();
 update private.notification_outbox set state='failed',last_error='Delivery uncertain beyond provider idempotency window; manual review required' where state in('pending','processing') and first_attempt_at<now()-interval '23 hours';
 return query with candidates as (
  select o.id from private.notification_outbox o where o.attempts<6 and ((o.state='pending' and o.available_at<=now()) or (o.state='processing' and o.lease_expires_at<now())) order by o.created_at for update skip locked limit 5
 ), claimed as (
  update private.notification_outbox o set state='processing',attempts=o.attempts+1,lease_token=gen_random_uuid(),lease_expires_at=now()+interval '5 minutes',text_snapshot=case when o.action_path is not null and o.first_attempt_at is null then o.text_snapshot||p_app_origin||o.action_path else o.text_snapshot end,first_attempt_at=coalesce(o.first_attempt_at,now()),sender=coalesce(o.sender,p_sender),recipient=coalesce(o.recipient,p_recipient) from candidates c where o.id=c.id returning o.*
 ) select c.id,e.id,c.lease_token,coalesce(e.contact_name,''),coalesce(e.contact_email,''),coalesce(e.phone,''),coalesce(e.message,''),c.target_title,c.sender,c.recipient,c.subject_snapshot,c.text_snapshot from claimed c left join public.enquiries e on e.id=c.enquiry_id;
end $$;
revoke all on function public.claim_transactional_notifications(text,text,text) from public,anon,authenticated;
grant execute on function public.claim_transactional_notifications(text,text,text) to service_role;

create or replace function public.notification_attempt_current(p_id uuid,p_lease_token uuid) returns boolean language sql security invoker set search_path='' as $$
 select exists(select 1 from private.notification_outbox o where o.id=p_id and o.lease_token=p_lease_token and o.state='processing' and o.lease_expires_at>now() and (o.maintenance_event_id is null or private.maintenance_outbox_current(o.maintenance_event_id,o.recipient)) and (o.open_house_notice_id is null or private.open_house_notice_current(o.open_house_notice_id)) and (o.cosigner_id is null or exists(select 1 from public.application_cosigners c join public.rental_applications a on a.id=c.application_id where c.id=o.cosigner_id and c.state='pending' and c.expires_at>now() and a.status in('submitted','under_review','needs_info'))));
$$;
revoke all on function public.notification_attempt_current(uuid,uuid) from public,anon,authenticated;
grant execute on function public.notification_attempt_current(uuid,uuid) to service_role;
