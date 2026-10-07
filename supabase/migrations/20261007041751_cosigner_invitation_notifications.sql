alter table private.notification_outbox add column cosigner_id uuid references public.application_cosigners(id),add column action_path text;
alter table private.notification_outbox drop constraint notification_outbox_entity;
alter table private.notification_outbox add constraint notification_outbox_entity check(num_nonnulls(enquiry_id,viewing_event_id,seller_lead_id,application_event_id,cosigner_id)=1);
create unique index notification_outbox_cosigner_idx on private.notification_outbox(cosigner_id) where cosigner_id is not null;
create function private.queue_cosigner_invitation() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.applicant_user_id is distinct from auth.uid() or private.verified_cosigner_email() is null or new.state<>'pending' or not exists(select 1 from public.rental_applications where id=new.application_id and user_id=auth.uid() and organization_id=new.organization_id and status in('submitted','under_review','needs_info')) then raise exception 'Verified applicant invitation required' using errcode='42501';end if;
 insert into private.notification_outbox(cosigner_id,audience,target_title,recipient,subject_snapshot,text_snapshot,action_path) values(new.id,'prospect',new.title_snapshot,new.invite_email,'Private co-signer review invitation',E'Open House Realty co-signer review invitation\n\n'||new.applicant_name_snapshot||' invited you to participate in a rental application review.'||E'\nProperty: '||new.title_snapshot||E'\nArea: '||new.area_snapshot||E'\nAdvertised monthly rent: JMD '||new.rent_jmd_snapshot::text||E'\nInvitation expires: '||to_char(new.expires_at at time zone 'America/Jamaica','YYYY-MM-DD HH24:MI')||E' (Jamaica)\n\nReview consent does not sign a lease or create a guarantee. Open the private link and sign in with the invited email address to review or decline. If this invitation was unexpected, you may ignore it.\n\nReview invitation: ','/cosigners/'||new.id::text);
 return new;
end $$;
revoke all on function private.queue_cosigner_invitation() from public,anon,authenticated;
create trigger queue_cosigner_invitation after insert on public.application_cosigners for each row execute function private.queue_cosigner_invitation();
create function private.supersede_cosigner_invitation_notice() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.state<>'pending' then update private.notification_outbox set state='superseded',last_error='Invitation no longer pending',lease_token=null,lease_expires_at=null where cosigner_id=new.id and state in('pending','processing');end if;
 return new;
end $$;
revoke all on function private.supersede_cosigner_invitation_notice() from public,anon,authenticated;
create trigger supersede_cosigner_invitation_notice after update of state on public.application_cosigners for each row execute function private.supersede_cosigner_invitation_notice();
create function private.supersede_closed_application_invites() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status not in('submitted','under_review','needs_info') then update private.notification_outbox set state='superseded',last_error='Application invitation stage closed',lease_token=null,lease_expires_at=null where cosigner_id in(select id from public.application_cosigners where application_id=new.id) and state in('pending','processing');end if;
 return new;
end $$;
revoke all on function private.supersede_closed_application_invites() from public,anon,authenticated;
create trigger supersede_closed_application_invites after update of status on public.rental_applications for each row execute function private.supersede_closed_application_invites();
-- Older workers cannot send invitations without their canonical URL snapshot.
create or replace function public.claim_enquiry_notifications(p_sender text,p_recipient text) returns table(outbox_id uuid,enquiry_id uuid,lease_token uuid,contact_name text,contact_email text,phone text,message text,target_title text,sender text,recipient text,subject_snapshot text,text_snapshot text)
language plpgsql security invoker set search_path='' as $$
begin
 if p_sender is null or p_recipient is null or length(p_sender) not between 3 and 320 or length(p_recipient) not between 3 and 254 or p_sender ~ '[\r\n]' or p_recipient ~ '[\r\n]' then raise exception 'Invalid sender configuration' using errcode='22023'; end if;
 update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where state='processing' and attempts>=6 and lease_expires_at<now();
 update private.notification_outbox set state='failed',last_error='Delivery uncertain beyond provider idempotency window; manual review required' where state in('pending','processing') and first_attempt_at<now()-interval '23 hours';
 return query with candidates as (
  select o.id from private.notification_outbox o where o.cosigner_id is null and o.attempts<6 and ((o.state='pending' and o.available_at<=now()) or (o.state='processing' and o.lease_expires_at<now())) order by o.created_at for update skip locked limit 5
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
 if p_sender is null or p_recipient is null or length(p_sender) not between 3 and 320 or length(p_recipient) not between 3 and 254 or p_sender ~ '[\r\n]' or p_recipient ~ '[\r\n]' then raise exception 'Invalid sender configuration' using errcode='22023'; end if;
 update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where state='processing' and attempts>=6 and lease_expires_at<now();
 update private.notification_outbox set state='failed',last_error='Delivery uncertain beyond provider idempotency window; manual review required' where state in('pending','processing') and first_attempt_at<now()-interval '23 hours';
 return query with candidates as (
  select o.id from private.notification_outbox o where o.attempts<6 and ((o.state='pending' and o.available_at<=now()) or (o.state='processing' and o.lease_expires_at<now())) order by o.created_at for update skip locked limit 5
 ), claimed as (
  update private.notification_outbox o set state='processing',attempts=o.attempts+1,lease_token=gen_random_uuid(),lease_expires_at=now()+interval '5 minutes',text_snapshot=case when o.cosigner_id is not null and o.first_attempt_at is null then o.text_snapshot||p_app_origin||o.action_path else o.text_snapshot end,first_attempt_at=coalesce(o.first_attempt_at,now()),sender=coalesce(o.sender,p_sender),recipient=coalesce(o.recipient,p_recipient) from candidates c where o.id=c.id returning o.*
 ) select c.id,e.id,c.lease_token,coalesce(e.contact_name,''),coalesce(e.contact_email,''),coalesce(e.phone,''),coalesce(e.message,''),c.target_title,c.sender,c.recipient,c.subject_snapshot,c.text_snapshot from claimed c left join public.enquiries e on e.id=c.enquiry_id;
end $$;
revoke all on function public.claim_transactional_notifications(text,text,text) from public,anon,authenticated;
grant execute on function public.claim_transactional_notifications(text,text,text) to service_role;

create function public.notification_attempt_current(p_id uuid,p_lease_token uuid) returns boolean language sql security invoker set search_path='' as $$
 select exists(select 1 from private.notification_outbox o where o.id=p_id and o.lease_token=p_lease_token and o.state='processing' and o.lease_expires_at>now() and (o.cosigner_id is null or exists(select 1 from public.application_cosigners c join public.rental_applications a on a.id=c.application_id where c.id=o.cosigner_id and c.state='pending' and c.expires_at>now() and a.status in('submitted','under_review','needs_info'))));
$$;
revoke all on function public.notification_attempt_current(uuid,uuid) from public,anon,authenticated;
grant execute on function public.notification_attempt_current(uuid,uuid) to service_role;
