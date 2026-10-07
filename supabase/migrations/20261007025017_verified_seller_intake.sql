-- Retire unrestricted anonymous writes; legacy unrouted rows remain for review.
drop policy "public can create seller leads" on public.seller_leads;
revoke all on public.seller_leads from public,anon,authenticated;
alter table public.seller_leads
 add column organization_id uuid references public.organizations(id),
 add column realtor_id uuid references public.realtor_profiles(id),
 add column request_id uuid,
 add column area text,
 add column property_type text,
 add column message text,
 add column consented_at timestamptz,
 add column updated_at timestamptz not null default now(),
 add column listing_id uuid references public.listings(id),
 add constraint seller_lead_request_unique unique(user_id,request_id),
 add constraint seller_lead_verified_payload check(request_id is null or (organization_id is not null and realtor_id is not null and consented_at is not null and name is not null and length(trim(name)) between 2 and 120 and email is not null and phone is not null and length(phone)<=40 and length(trim(property_address)) between 5 and 300 and area is not null and length(trim(area)) between 2 and 120 and property_type is not null and property_type in('house','apartment','land','commercial','other') and message is not null and length(trim(message)) between 10 and 2000));
create index seller_leads_org_idx on public.seller_leads(organization_id,status,created_at desc);
create index seller_leads_user_idx on public.seller_leads(user_id,created_at desc);
create index seller_leads_realtor_idx on public.seller_leads(realtor_id);
grant select on public.seller_leads to authenticated;
grant select,insert,update on public.seller_leads to service_role;
create policy "sellers read own requests" on public.seller_leads for select to authenticated using(user_id=(select auth.uid()));
create policy "verified staff read organization seller requests" on public.seller_leads for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));
create table public.seller_lead_events (
 id uuid primary key default gen_random_uuid(),
 seller_lead_id uuid not null references public.seller_leads(id) on delete cascade,
 actor_user_id uuid not null references auth.users(id),
 old_status text,
 new_status text not null,
 reason text not null default '',
 created_at timestamptz not null default now()
);
create index seller_lead_events_lead_idx on public.seller_lead_events(seller_lead_id,created_at desc);
alter table public.seller_lead_events enable row level security;
revoke all on public.seller_lead_events from public,anon,authenticated;
grant select on public.seller_lead_events to authenticated;
grant select,insert on public.seller_lead_events to service_role;
create policy "read own accessible seller request history" on public.seller_lead_events for select to authenticated using(exists(select 1 from public.seller_leads where id=seller_lead_id));
alter table private.notification_outbox add column seller_lead_id uuid unique references public.seller_leads(id);
alter table private.notification_outbox drop constraint notification_outbox_entity;
alter table private.notification_outbox add constraint notification_outbox_entity check(num_nonnulls(enquiry_id,viewing_event_id,seller_lead_id)=1);

create function private.submit_seller_request(p_request_id uuid,p_realtor_id uuid,p_name text,p_phone text,p_property_address text,p_area text,p_property_type text,p_seller_intent text,p_message text,p_consent boolean)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); verified_email text; org uuid; realtor_name text; existing public.seller_leads; created uuid;
begin
 if caller is null then raise exception 'Authentication required' using errcode='42501';end if;
 select email into verified_email from auth.users where id=caller and email_confirmed_at is not null;
 if verified_email is null then raise exception 'Verified email required' using errcode='42501';end if;
 if p_request_id is null or p_realtor_id is null or p_consent is distinct from true or p_name is null or length(trim(p_name)) not between 2 and 120 or p_phone is null or length(p_phone)>40 or p_property_address is null or length(trim(p_property_address)) not between 5 and 300 or p_area is null or length(trim(p_area)) not between 2 and 120 or p_property_type is null or p_property_type not in('house','apartment','land','commercial','other') or p_seller_intent is null or p_seller_intent not in('curious','considering','soon','already_listed') or p_message is null or length(trim(p_message)) not between 10 and 2000 then raise exception 'Invalid seller request' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,99));
 select * into existing from public.seller_leads where user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.realtor_id<>p_realtor_id or existing.name<>trim(p_name) or existing.phone<>trim(p_phone) or existing.property_address<>trim(p_property_address) or existing.area<>trim(p_area) or existing.property_type<>p_property_type or existing.seller_intent<>p_seller_intent or existing.message<>trim(p_message) then raise exception 'Request ID already used' using errcode='22023';end if;
  return existing.id;
 end if;
 if (select count(*) from public.seller_leads where user_id=caller and created_at>now()-interval '1 day')>=3 then raise exception 'Seller request limit reached' using errcode='P0001';end if;
 select organization_id,display_name into org,realtor_name from public.realtor_profiles where id=p_realtor_id and is_published and 'sell'=any(supported_intents);
 if org is null then raise exception 'Sales realtor unavailable' using errcode='22023';end if;
 insert into public.seller_leads(user_id,organization_id,realtor_id,request_id,name,email,phone,property_address,area,property_type,seller_intent,message,consented_at) values(caller,org,p_realtor_id,p_request_id,trim(p_name),verified_email,trim(p_phone),trim(p_property_address),trim(p_area),p_property_type,p_seller_intent,trim(p_message),now()) returning id into created;
 insert into public.seller_lead_events(seller_lead_id,actor_user_id,new_status) values(created,caller,'new');
 insert into private.notification_outbox(seller_lead_id,audience,target_title,subject_snapshot,text_snapshot) values(created,'business','Seller property review','New seller property-review request',E'New Open House seller request\n\nReference: '||created::text||E'\nSelected realtor: '||realtor_name||E'\nSeller: '||trim(p_name)||E'\nVerified email: '||verified_email||E'\nPhone: '||trim(p_phone)||E'\nPrivate property address: '||trim(p_property_address)||E'\nArea: '||trim(p_area)||E'\nType: '||p_property_type||E'\nTiming: '||p_seller_intent||E'\n\n'||trim(p_message)||E'\n\nReview this request in the staff seller inbox. Do not publish the address without an approved listing review.');
 return created;
end $$;
revoke all on function private.submit_seller_request(uuid,uuid,text,text,text,text,text,text,text,boolean) from public,anon;
grant execute on function private.submit_seller_request(uuid,uuid,text,text,text,text,text,text,text,boolean) to authenticated;
create function public.submit_seller_request(p_request_id uuid,p_realtor_id uuid,p_name text,p_phone text,p_property_address text,p_area text,p_property_type text,p_seller_intent text,p_message text,p_consent boolean) returns uuid language sql security invoker set search_path='' as $$ select private.submit_seller_request(p_request_id,p_realtor_id,p_name,p_phone,p_property_address,p_area,p_property_type,p_seller_intent,p_message,p_consent); $$;
revoke all on function public.submit_seller_request(uuid,uuid,text,text,text,text,text,text,text,boolean) from public,anon;
grant execute on function public.submit_seller_request(uuid,uuid,text,text,text,text,text,text,text,boolean) to authenticated;

create function private.transition_seller_request(p_id uuid,p_status text,p_reason text,p_expected_status text) returns text language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); lead public.seller_leads; org uuid;
begin
 org:=private.verified_enquiry_staff_organization();
 if caller is null or org is null then raise exception 'Verified staff required' using errcode='42501';end if;
 select * into lead from public.seller_leads where id=p_id for update;
 if lead.id is null or lead.organization_id is distinct from org then raise exception 'Seller request unavailable' using errcode='42501';end if;
 if p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'A shared follow-up reason is required' using errcode='22023';end if;
 if lead.status=p_status then return lead.status;end if;
 if lead.status is distinct from p_expected_status then raise exception 'Seller request changed; refresh first' using errcode='40001';end if;
 if not ((lead.status='new' and p_status='contacted') or (lead.status='contacted' and p_status='market_review') or (lead.status='market_review' and p_status='proposal') or (lead.status in('new','contacted','market_review','proposal') and p_status in('closed','lost'))) then raise exception 'Invalid seller stage transition' using errcode='22023';end if;
 update public.seller_leads set status=p_status,updated_at=now() where id=lead.id;
 insert into public.seller_lead_events(seller_lead_id,actor_user_id,old_status,new_status,reason) values(lead.id,caller,lead.status,p_status,trim(p_reason));
 return p_status;
end $$;
revoke all on function private.transition_seller_request(uuid,text,text,text) from public,anon;
grant execute on function private.transition_seller_request(uuid,text,text,text) to authenticated;
create function public.transition_seller_request(p_id uuid,p_status text,p_reason text,p_expected_status text) returns text language sql security invoker set search_path='' as $$ select private.transition_seller_request(p_id,p_status,p_reason,p_expected_status); $$;
revoke all on function public.transition_seller_request(uuid,text,text,text) from public,anon;
grant execute on function public.transition_seller_request(uuid,text,text,text) to authenticated;
