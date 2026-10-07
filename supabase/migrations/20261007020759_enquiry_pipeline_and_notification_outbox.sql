create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;

create table public.enquiries (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id),
 organization_id uuid not null references public.organizations(id),
 listing_id uuid references public.listings(id),
 realtor_id uuid references public.realtor_profiles(id),
 request_id uuid not null,
 contact_name text not null check (length(trim(contact_name)) between 2 and 120),
 contact_email text not null,
 phone text not null default '' check (length(phone) <= 40),
 message text not null check (length(trim(message)) between 10 and 4000),
 consented_at timestamptz not null default now(),
 status text not null default 'new' check (status in ('new','contacted','closed')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(user_id,request_id),
 check ((listing_id is not null)::integer + (realtor_id is not null)::integer = 1)
);
create index enquiries_organization_idx on public.enquiries(organization_id,status,created_at desc);
create index enquiries_user_idx on public.enquiries(user_id,created_at desc);
create index enquiries_listing_idx on public.enquiries(listing_id);
create index enquiries_realtor_idx on public.enquiries(realtor_id);
alter table public.enquiries enable row level security;
revoke all on public.enquiries from anon, authenticated;
grant select on public.enquiries to authenticated;
grant select,insert,update on public.enquiries to service_role;
grant update(status) on public.enquiries to authenticated;
create policy "prospects read own enquiries" on public.enquiries for select to authenticated using (user_id=(select auth.uid()));
create policy "staff read own organization enquiries" on public.enquiries for select to authenticated using (organization_id in (select organization_id from public.staff_accounts where user_id=(select auth.uid()) and role in ('admin','realtor','manager')));
create policy "staff update enquiry status" on public.enquiries for update to authenticated using (organization_id in (select organization_id from public.staff_accounts where user_id=(select auth.uid()) and role in ('admin','realtor','manager'))) with check (organization_id in (select organization_id from public.staff_accounts where user_id=(select auth.uid()) and role in ('admin','realtor','manager')));

create table public.enquiry_events (
 id uuid primary key default gen_random_uuid(),
 enquiry_id uuid not null references public.enquiries(id) on delete cascade,
 actor_user_id uuid not null references auth.users(id),
 event_name text not null,
 old_status text,
 new_status text,
 created_at timestamptz not null default now()
);
create index enquiry_events_enquiry_idx on public.enquiry_events(enquiry_id,created_at);
alter table public.enquiry_events enable row level security;
revoke all on public.enquiry_events from anon,authenticated;
grant select on public.enquiry_events to authenticated;
grant select,insert on public.enquiry_events to service_role;
create policy "read events for accessible enquiries" on public.enquiry_events for select to authenticated using (exists(select 1 from public.enquiries where id=enquiry_id));

create table private.notification_outbox (
 id uuid primary key default gen_random_uuid(),
 enquiry_id uuid not null unique references public.enquiries(id),
 state text not null default 'pending' check (state in ('pending','processing','sent','failed')),
 attempts integer not null default 0,
 available_at timestamptz not null default now(),
 lease_token uuid,
 lease_expires_at timestamptz,
 first_attempt_at timestamptz,
 provider_id text,
 last_error text,
 created_at timestamptz not null default now(),
 sent_at timestamptz
);
create index notification_outbox_pending_idx on private.notification_outbox(state,available_at);
alter table private.notification_outbox enable row level security;
revoke all on private.notification_outbox from public,anon,authenticated;
grant select,insert,update on private.notification_outbox to service_role;

-- Privileged internals are private, have empty search paths and verify the caller.
create function private.create_enquiry(p_request_id uuid,p_listing_id uuid,p_realtor_id uuid,p_contact_name text,p_phone text,p_message text,p_consent boolean)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); email_address text; org uuid; existing public.enquiries; created_id uuid;
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
 if p_listing_id is not null then select organization_id into org from public.listings where id=p_listing_id and status='published';
 else select organization_id into org from public.realtor_profiles where id=p_realtor_id and is_published; end if;
 if org is null then raise exception 'Target unavailable' using errcode='22023'; end if;
 insert into public.enquiries(user_id,organization_id,listing_id,realtor_id,request_id,contact_name,contact_email,phone,message) values(caller,org,p_listing_id,p_realtor_id,p_request_id,trim(p_contact_name),email_address,trim(p_phone),trim(p_message)) returning id into created_id;
 insert into public.enquiry_events(enquiry_id,actor_user_id,event_name,new_status) values(created_id,caller,'submitted','new');
 insert into private.notification_outbox(enquiry_id) values(created_id);
 return created_id;
end $$;
revoke all on function private.create_enquiry(uuid,uuid,uuid,text,text,text,boolean) from public,anon;
grant execute on function private.create_enquiry(uuid,uuid,uuid,text,text,text,boolean) to authenticated;
create function public.submit_enquiry(p_request_id uuid,p_listing_id uuid,p_realtor_id uuid,p_contact_name text,p_phone text,p_message text,p_consent boolean)
returns uuid language sql security invoker set search_path='' as $$ select private.create_enquiry(p_request_id,p_listing_id,p_realtor_id,p_contact_name,p_phone,p_message,p_consent); $$;
revoke all on function public.submit_enquiry(uuid,uuid,uuid,text,text,text,boolean) from public,anon;
grant execute on function public.submit_enquiry(uuid,uuid,uuid,text,text,text,boolean) to authenticated;

create function private.audit_enquiry_status() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.staff_accounts where user_id=auth.uid() and organization_id=old.organization_id and role in ('admin','realtor','manager')) then raise exception 'Staff authorization required' using errcode='42501'; end if;
 if new.status<>old.status then
  new.updated_at:=now();
  insert into public.enquiry_events(enquiry_id,actor_user_id,event_name,old_status,new_status) values(old.id,auth.uid(),'status_changed',old.status,new.status);
 end if;
 return new;
end $$;
revoke all on function private.audit_enquiry_status() from public,anon,authenticated;
create trigger audit_enquiry_status before update on public.enquiries for each row execute function private.audit_enquiry_status();

-- Worker operations require a server-only service credential, not a user session.
create function public.claim_enquiry_notifications() returns table(outbox_id uuid,enquiry_id uuid,lease_token uuid,contact_name text,contact_email text,phone text,message text,target_title text)
language plpgsql security invoker set search_path='' as $$
begin
 update private.notification_outbox set state='failed',last_error='Worker attempt limit reached; manual review required' where state='processing' and attempts>=6 and lease_expires_at<now();
 update private.notification_outbox set state='failed',last_error='Delivery uncertain beyond provider idempotency window; manual review required' where state in ('pending','processing') and first_attempt_at<now()-interval '23 hours';
 return query with candidates as (
  select o.id from private.notification_outbox o where o.attempts<6 and ((o.state='pending' and o.available_at<=now()) or (o.state='processing' and o.lease_expires_at<now())) order by o.created_at for update skip locked limit 5
 ), claimed as (
  update private.notification_outbox o set state='processing',attempts=o.attempts+1,lease_token=gen_random_uuid(),lease_expires_at=now()+interval '5 minutes',first_attempt_at=coalesce(o.first_attempt_at,now()) from candidates c where o.id=c.id returning o.*
 ) select c.id,e.id,c.lease_token,e.contact_name,e.contact_email,e.phone,e.message,coalesce(l.title,r.display_name,'Open House enquiry') from claimed c join public.enquiries e on e.id=c.enquiry_id left join public.listings l on l.id=e.listing_id left join public.realtor_profiles r on r.id=e.realtor_id;
end $$;
revoke all on function public.claim_enquiry_notifications() from public,anon,authenticated;
grant execute on function public.claim_enquiry_notifications() to service_role;
create function public.complete_enquiry_notification(p_id uuid,p_lease_token uuid,p_provider_id text,p_success boolean)
returns boolean language plpgsql security invoker set search_path='' as $$
declare changed integer;
begin
 update private.notification_outbox set state=case when p_success then 'sent' when attempts>=6 then 'failed' else 'pending' end,provider_id=case when p_success then p_provider_id else null end,sent_at=case when p_success then now() else null end,last_error=case when p_success then null else 'Provider request failed; retry scheduled' end,available_at=now()+interval '5 minutes'*power(2,least(attempts,5)),lease_token=null,lease_expires_at=null where id=p_id and lease_token=p_lease_token and state='processing' and lease_expires_at>now();
 get diagnostics changed=row_count;
 return changed=1;
end $$;
revoke all on function public.complete_enquiry_notification(uuid,uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.complete_enquiry_notification(uuid,uuid,text,boolean) to service_role;
