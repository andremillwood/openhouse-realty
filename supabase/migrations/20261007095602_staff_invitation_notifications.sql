alter table private.notification_outbox add column staff_invitation_id uuid references public.staff_invitations(id);
alter table private.notification_outbox drop constraint notification_outbox_entity;
alter table private.notification_outbox add constraint notification_outbox_entity check(num_nonnulls(enquiry_id,viewing_event_id,seller_lead_id,application_event_id,cosigner_id,open_house_notice_id,maintenance_event_id,staff_invitation_id)=1);
alter table private.notification_outbox drop constraint notification_outbox_audience_check;
alter table private.notification_outbox add constraint notification_outbox_audience_check check(audience in('business','prospect','contractor','staff'));
create unique index notification_outbox_staff_invitation_idx on private.notification_outbox(staff_invitation_id) where staff_invitation_id is not null;
create function private.staff_invitation_notice_current(p_id uuid,p_recipient text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.staff_invitations i join public.staff_accounts a on a.user_id=i.created_by and a.organization_id=i.organization_id and a.role='admin' join auth.users u on u.id=a.user_id where i.id=p_id and i.state='pending' and i.expires_at>statement_timestamp() and i.invite_email=p_recipient and u.email_confirmed_at is not null
 and not exists(select 1 from public.staff_accounts s join auth.users recipient on recipient.id=s.user_id where lower(recipient.email)=i.invite_email));
$$;
revoke all on function private.staff_invitation_notice_current(uuid,text) from public,anon,authenticated,service_role;
grant execute on function private.staff_invitation_notice_current(uuid,text) to service_role;
create function private.queue_staff_invitation_notice() returns trigger language plpgsql security definer set search_path='' as $$
declare org_name text;
begin
 if new.created_by is distinct from auth.uid() or private.verified_staff_admin_organization() is distinct from new.organization_id or new.state<>'pending' then raise exception 'Current administrator-approved invitation required' using errcode='42501';end if;
 select name into org_name from public.organizations where id=new.organization_id;
 insert into private.notification_outbox(staff_invitation_id,audience,target_title,recipient,subject_snapshot,text_snapshot,action_path)
 values(new.id,'staff','Staff invitation',new.invite_email,'Your Open House Realty team invitation',E'You have been invited to join '||org_name||E'.\n\nApproved role: '||new.role||E'\nExpires: '||to_char(new.expires_at at time zone 'America/Jamaica','YYYY-MM-DD HH24:MI')||E' (Jamaica time)\n\nSign up or sign in and verify the invited email address to review the organization and role, then accept or decline. This invitation does not grant access until you accept. If you do not recognize the invitation, contact the organization before accepting.\n\nReview invitation: ','/account/invitations/'||new.id::text);
 return new;
end $$;
revoke all on function private.queue_staff_invitation_notice() from public,anon,authenticated,service_role;
create trigger queue_staff_invitation_notice after insert on public.staff_invitations for each row execute function private.queue_staff_invitation_notice();
create function private.supersede_staff_invitation_notice() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.state<>'pending' then update private.notification_outbox set state='superseded',last_error='Staff invitation closed',lease_token=null,lease_expires_at=null where staff_invitation_id=new.id and state in('pending','processing');end if;
 return new;
end $$;
revoke all on function private.supersede_staff_invitation_notice() from public,anon,authenticated,service_role;
create trigger supersede_staff_invitation_notice after update of state on public.staff_invitations for each row execute function private.supersede_staff_invitation_notice();

create or replace function private.bind_notification_organization() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 new.organization_id:=coalesce((select organization_id from public.enquiries where id=new.enquiry_id),(select v.organization_id from public.viewing_events e join public.viewings v on v.id=e.viewing_id where e.id=new.viewing_event_id),(select organization_id from public.seller_leads where id=new.seller_lead_id),(select a.organization_id from public.rental_application_events e join public.rental_applications a on a.id=e.application_id where e.id=new.application_event_id),(select organization_id from public.application_cosigners where id=new.cosigner_id),(select organization_id from private.open_house_notices where id=new.open_house_notice_id),(select organization_id from private.maintenance_notification_events where id=new.maintenance_event_id),(select organization_id from public.staff_invitations where id=new.staff_invitation_id));
 if new.organization_id is null then raise exception 'Notification organization unavailable' using errcode='22023';end if;return new;
end $$;
create or replace function public.claim_enquiry_notifications(p_sender text,p_recipient text) returns table(outbox_id uuid,enquiry_id uuid,lease_token uuid,contact_name text,contact_email text,phone text,message text,target_title text,sender text,recipient text,subject_snapshot text,text_snapshot text)
language plpgsql security invoker set search_path='' as $$
begin
 update private.notification_outbox o set state='superseded',last_error='Staff invitation expired, closed or approval changed',lease_token=null,lease_expires_at=null where o.staff_invitation_id is not null and o.state in('pending','processing') and not private.staff_invitation_notice_current(o.staff_invitation_id,o.recipient);
 update private.notification_outbox o set state='superseded',last_error='Maintenance notice no longer current',lease_token=null,lease_expires_at=null where o.maintenance_event_id is not null and o.state in('pending','processing') and not private.maintenance_outbox_current(o.maintenance_event_id,o.recipient);
 update private.notification_outbox o set state='superseded',last_error='Open house notice expired or changed',lease_token=null,lease_expires_at=null where o.open_house_notice_id is not null and o.state in('pending','processing') and not private.open_house_notice_current(o.open_house_notice_id);
 if p_sender is null or p_recipient is null or length(p_sender) not between 3 and 320 or length(p_recipient) not between 3 and 254 or p_sender ~ '[\r\n]' or p_recipient ~ '[\r\n]' then raise exception 'Invalid sender configuration' using errcode='22023'; end if;
 update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where state='processing' and attempts>=6 and lease_expires_at<now();
 update private.notification_outbox set state='failed',last_error='Delivery uncertain beyond provider idempotency window; manual review required' where state in('pending','processing') and first_attempt_at<now()-interval '23 hours';
 return query with candidates as (
  select o.id from private.notification_outbox o where o.staff_invitation_id is null and o.cosigner_id is null and o.open_house_notice_id is null and o.maintenance_event_id is null and o.attempts<6 and ((o.state='pending' and o.available_at<=now()) or (o.state='processing' and o.lease_expires_at<now())) order by o.created_at for update skip locked limit 5
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
 update private.notification_outbox o set state='superseded',last_error='Staff invitation expired, closed or approval changed',lease_token=null,lease_expires_at=null where o.staff_invitation_id is not null and o.state in('pending','processing') and not private.staff_invitation_notice_current(o.staff_invitation_id,o.recipient);
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
 select exists(select 1 from private.notification_outbox o where o.id=p_id and o.lease_token=p_lease_token and o.state='processing' and o.lease_expires_at>now() and (o.staff_invitation_id is null or private.staff_invitation_notice_current(o.staff_invitation_id,o.recipient)) and (o.maintenance_event_id is null or private.maintenance_outbox_current(o.maintenance_event_id,o.recipient)) and (o.open_house_notice_id is null or private.open_house_notice_current(o.open_house_notice_id)) and (o.cosigner_id is null or exists(select 1 from public.application_cosigners c join public.rental_applications a on a.id=c.application_id where c.id=o.cosigner_id and c.state='pending' and c.expires_at>now() and a.status in('submitted','under_review','needs_info'))));
$$;
revoke all on function public.notification_attempt_current(uuid,uuid) from public,anon,authenticated;
grant execute on function public.notification_attempt_current(uuid,uuid) to service_role;


create or replace function private.staff_notification_monitor(p_state text,p_family text,p_page integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid:=private.verified_enquiry_staff_organization();result jsonb;
begin
 if auth.uid() is null or org is null then raise exception 'Verified organization staff required' using errcode='42501';end if;
 if p_state is null or p_state not in('all','pending','processing','sent','failed','superseded') or p_family is null or p_family not in('all','enquiry','viewing','seller','application','cosigner','open_house','maintenance','staff_invitation') or p_page is null or p_page not between 1 and 99999 then raise exception 'Valid monitor filters and page required' using errcode='22023';end if;
 with scoped as materialized (
  select o.id,o.state,o.audience,o.target_title,o.attempts,o.created_at,o.available_at,o.first_attempt_at,o.sent_at,o.last_error,
   case when o.enquiry_id is not null then 'enquiry' when o.viewing_event_id is not null then 'viewing' when o.seller_lead_id is not null then 'seller' when o.application_event_id is not null then 'application' when o.cosigner_id is not null then 'cosigner' when o.open_house_notice_id is not null then 'open_house' when o.maintenance_event_id is not null then 'maintenance' else 'staff_invitation' end family
  from private.notification_outbox o where o.organization_id=org and (o.staff_invitation_id is null or private.verified_staff_admin_organization()=org)
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
 if p_state is null or p_state not in('all','pending','processing','sent','failed','superseded') or p_family is null or p_family not in('all','enquiry','viewing','seller','application','cosigner','open_house','maintenance','staff_invitation') or p_delivery is null or p_delivery not in('all','unknown','sent','delivered','delayed','bounced','complained','failed','suppressed') or p_page is null or p_page not between 1 and 99999 then raise exception 'Valid monitor filters and page required' using errcode='22023';end if;
 with scoped as materialized (
  select o.id,o.state,o.audience,o.target_title,o.attempts,o.created_at,o.available_at,o.first_attempt_at,o.sent_at,o.last_error,o.delivery_state,o.delivery_event_at,
   case when o.enquiry_id is not null then 'enquiry' when o.viewing_event_id is not null then 'viewing' when o.seller_lead_id is not null then 'seller' when o.application_event_id is not null then 'application' when o.cosigner_id is not null then 'cosigner' when o.open_house_notice_id is not null then 'open_house' when o.maintenance_event_id is not null then 'maintenance' else 'staff_invitation' end family
  from private.notification_outbox o where o.organization_id=org and (o.staff_invitation_id is null or private.verified_staff_admin_organization()=org)
 ), filtered as materialized (select * from scoped where (p_state='all' or state=p_state) and (p_family='all' or family=p_family) and (p_delivery='all' or delivery_state=p_delivery)), totals as (
  select count(*) total,greatest(1,ceil(count(*)::numeric/25)::integer) pages from filtered
 ), page_rows as (
  select * from filtered order by created_at desc,id offset (select (least(p_page,pages)-1)*25 from totals) limit 25
 ) select jsonb_build_object('total',t.total,'pages',t.pages,'page',least(p_page,t.pages),'counts',(select coalesce(jsonb_object_agg(state,n),'{}'::jsonb) from(select state,count(*) n from scoped group by state)c),'delivery_counts',(select coalesce(jsonb_object_agg(delivery_state,n),'{}'::jsonb) from(select delivery_state,count(*) n from scoped group by delivery_state)d),'rows',(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) from page_rows r)) into result from totals t;
 return result;
end $$;
