alter table private.notification_outbox add column target_title text not null default 'Open House enquiry', add column sender text, add column recipient text;
update private.notification_outbox o set target_title=coalesce(l.title,r.display_name,'Open House enquiry') from public.enquiries e left join public.listings l on l.id=e.listing_id left join public.realtor_profiles r on r.id=e.realtor_id where e.id=o.enquiry_id;
-- Do not guess payload identity for previously attempted deliveries.
update private.notification_outbox set state='failed',last_error='Payload snapshot introduced after prior attempt; manual reconciliation required' where first_attempt_at is not null and state in ('pending','processing');
create or replace function private.create_enquiry(p_request_id uuid,p_listing_id uuid,p_realtor_id uuid,p_contact_name text,p_phone text,p_message text,p_consent boolean)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); email_address text; org uuid; target_name text; existing public.enquiries; created_id uuid;
begin
 if caller is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select email into email_address from auth.users where id=caller and email_confirmed_at is not null;
 if email_address is null then raise exception 'Verified email required' using errcode='42501'; end if;
 if p_consent is distinct from true or p_request_id is null or p_contact_name is null or length(trim(p_contact_name)) not between 2 and 120 or p_phone is null or length(p_phone)>40 or p_message is null or length(trim(p_message)) not between 10 and 4000 then raise exception 'Invalid enquiry' using errcode='22023'; end if;
 if (p_listing_id is null) = (p_realtor_id is null) then raise exception 'Choose one enquiry target' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,42));
 select * into existing from public.enquiries where user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.listing_id is distinct from p_listing_id or existing.realtor_id is distinct from p_realtor_id or existing.contact_name<>trim(p_contact_name) or existing.phone<>trim(p_phone) or existing.message<>trim(p_message) then raise exception 'Request ID already used' using errcode='22023'; end if;
  return existing.id;
 end if;
 if (select count(*) from public.enquiries where user_id=caller and created_at>now()-interval '1 hour') >= 5 or (select count(*) from public.enquiries where user_id=caller and created_at>now()-interval '1 day') >= 20 then raise exception 'Enquiry rate limit reached' using errcode='P0001'; end if;
 if p_listing_id is not null then select organization_id,title into org,target_name from public.listings where id=p_listing_id and status='published';
 else select organization_id,display_name into org,target_name from public.realtor_profiles where id=p_realtor_id and is_published; end if;
 if org is null then raise exception 'Target unavailable' using errcode='22023'; end if;
 insert into public.enquiries(user_id,organization_id,listing_id,realtor_id,request_id,contact_name,contact_email,phone,message) values(caller,org,p_listing_id,p_realtor_id,p_request_id,trim(p_contact_name),email_address,trim(p_phone),trim(p_message)) returning id into created_id;
 insert into public.enquiry_events(enquiry_id,actor_user_id,event_name,new_status) values(created_id,caller,'submitted','new');
 insert into private.notification_outbox(enquiry_id,target_title) values(created_id,target_name);
 return created_id;
end $$;

drop function public.claim_enquiry_notifications();
create function public.claim_enquiry_notifications(p_sender text,p_recipient text) returns table(outbox_id uuid,enquiry_id uuid,lease_token uuid,contact_name text,contact_email text,phone text,message text,target_title text,sender text,recipient text)
language plpgsql security invoker set search_path='' as $$
begin
 if p_sender is null or p_recipient is null or length(p_sender) not between 3 and 320 or length(p_recipient) not between 3 and 254 or p_sender ~ '[\r\n]' or p_recipient ~ '[\r\n]' then raise exception 'Invalid sender configuration' using errcode='22023'; end if;
 update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where state='processing' and attempts>=6 and lease_expires_at<now();
 update private.notification_outbox set state='failed',last_error='Delivery uncertain beyond provider idempotency window; manual review required' where state in ('pending','processing') and first_attempt_at<now()-interval '23 hours';
 return query with candidates as (
  select o.id from private.notification_outbox o where o.attempts<6 and ((o.state='pending' and o.available_at<=now()) or (o.state='processing' and o.lease_expires_at<now())) order by o.created_at for update skip locked limit 5
 ), claimed as (
  update private.notification_outbox o set state='processing',attempts=o.attempts+1,lease_token=gen_random_uuid(),lease_expires_at=now()+interval '5 minutes',first_attempt_at=coalesce(o.first_attempt_at,now()),sender=coalesce(o.sender,p_sender),recipient=coalesce(o.recipient,p_recipient) from candidates c where o.id=c.id returning o.*
 ) select c.id,e.id,c.lease_token,e.contact_name,e.contact_email,e.phone,e.message,c.target_title,c.sender,c.recipient from claimed c join public.enquiries e on e.id=c.enquiry_id;
end $$;
revoke all on function public.claim_enquiry_notifications(text,text) from public,anon,authenticated;
grant execute on function public.claim_enquiry_notifications(text,text) to service_role;
