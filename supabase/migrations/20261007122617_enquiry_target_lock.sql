create or replace function private.create_enquiry(p_request_id uuid,p_listing_id uuid,p_realtor_id uuid,p_contact_name text,p_phone text,p_message text,p_consent boolean)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); email_address text; org uuid; target_name text; existing public.enquiries; created_id uuid;
begin
 if caller is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_consent is distinct from true or p_request_id is null or p_contact_name is null or length(trim(p_contact_name)) not between 2 and 120 or p_phone is null or length(p_phone)>40 or p_message is null or length(trim(p_message)) not between 10 and 4000 then raise exception 'Invalid enquiry' using errcode='22023'; end if;
 if (p_listing_id is null) = (p_realtor_id is null) then raise exception 'Choose one enquiry target' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,42));
 -- Recheck after waiting and retain verified identity until commit.
 select email into email_address from auth.users where id=caller and email_confirmed_at is not null for share;
 if email_address is null then raise exception 'Verified email required' using errcode='42501'; end if;
 select * into existing from public.enquiries where user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.listing_id is distinct from p_listing_id or existing.realtor_id is distinct from p_realtor_id or existing.contact_name<>trim(p_contact_name) or existing.phone<>trim(p_phone) or existing.message<>trim(p_message) then raise exception 'Request ID already used' using errcode='22023'; end if;
  return existing.id;
 end if;
 if (select count(*) from public.enquiries where user_id=caller and created_at>now()-interval '1 hour') >= 5 or (select count(*) from public.enquiries where user_id=caller and created_at>now()-interval '1 day') >= 20 then raise exception 'Enquiry rate limit reached' using errcode='P0001'; end if;
 if p_listing_id is not null then select organization_id,title into org,target_name from public.listings where id=p_listing_id and status='published' for share;
 else select organization_id,display_name into org,target_name from public.realtor_profiles where id=p_realtor_id and is_published for share; end if;
 if org is null then raise exception 'Target unavailable' using errcode='22023'; end if;
 insert into public.enquiries(user_id,organization_id,listing_id,realtor_id,request_id,contact_name,contact_email,phone,message) values(caller,org,p_listing_id,p_realtor_id,p_request_id,trim(p_contact_name),email_address,trim(p_phone),trim(p_message)) returning id into created_id;
 insert into public.enquiry_events(enquiry_id,actor_user_id,event_name,new_status) values(created_id,caller,'submitted','new');
 insert into private.notification_outbox(enquiry_id,target_title) values(created_id,target_name);
 return created_id;
end $$;
