create function private.verified_catalog_organization() returns uuid language sql stable security definer set search_path='' as $$
 select s.organization_id from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=auth.uid() and u.email_confirmed_at is not null and s.role in('admin','realtor');
$$;
revoke all on function private.verified_catalog_organization() from public,anon;
grant execute on function private.verified_catalog_organization() to authenticated;
alter policy "catalog staff read own listings" on public.listings using(organization_id=(select private.verified_catalog_organization()));
alter policy "catalog staff create own listings" on public.listings with check(organization_id=(select private.verified_catalog_organization()));
alter policy "catalog staff update own listings" on public.listings using(organization_id=(select private.verified_catalog_organization())) with check(organization_id=(select private.verified_catalog_organization()));
alter policy "catalog staff read own realtor_profiles" on public.realtor_profiles using(organization_id=(select private.verified_catalog_organization()));
alter policy "catalog staff create own realtor_profiles" on public.realtor_profiles with check(organization_id=(select private.verified_catalog_organization()));
alter policy "catalog staff update own realtor_profiles" on public.realtor_profiles using(organization_id=(select private.verified_catalog_organization())) with check(organization_id=(select private.verified_catalog_organization()));
grant select on public.properties to authenticated;
grant select,insert,update on public.properties to service_role;
create policy "verified staff read private organization properties" on public.properties for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));
create index properties_organization_idx on public.properties(organization_id);
create index seller_leads_listing_idx on public.seller_leads(listing_id);
grant select on public.units to authenticated;
grant select,insert,update on public.units to service_role;
create policy "verified staff read private organization units" on public.units for select to authenticated using(exists(select 1 from public.properties p where p.id=property_id and p.organization_id=(select private.verified_enquiry_staff_organization())));
create index listings_unit_idx on public.listings(unit_id);
create index listings_property_idx on public.listings(property_id);

create table public.seller_listing_handoffs (
 id uuid primary key default gen_random_uuid(),
 seller_lead_id uuid not null unique references public.seller_leads(id),
 organization_id uuid not null references public.organizations(id),
 property_id uuid not null unique references public.properties(id),
 listing_id uuid not null unique references public.listings(id),
 request_id uuid not null,
 approved_by uuid not null references auth.users(id),
 approved_at timestamptz not null default now(),
 approval_reason text not null check(length(trim(approval_reason)) between 5 and 500),
 public_title text not null,
 public_area text not null,
 property_type text not null,
 unique(organization_id,request_id)
);
create index seller_listing_handoffs_org_idx on public.seller_listing_handoffs(organization_id,approved_at desc);
alter table public.seller_listing_handoffs enable row level security;
revoke all on public.seller_listing_handoffs from public,anon,authenticated;
grant select on public.seller_listing_handoffs to authenticated;
grant select,insert on public.seller_listing_handoffs to service_role;
create policy "staff read own organization seller handoffs" on public.seller_listing_handoffs for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));

-- Invoker trigger: staff can see their own properties; foreign/unknown links fail alike.
create function private.guard_listing_property_relation() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.property_id is not null and not exists(select 1 from public.properties p where p.id=new.property_id and p.organization_id=new.organization_id) then raise exception 'Property relation unavailable' using errcode='22023';end if;
 if new.unit_id is not null and (new.property_id is null or not exists(select 1 from public.units u where u.id=new.unit_id and u.property_id=new.property_id)) then raise exception 'Unit relation unavailable' using errcode='22023';end if;
 if exists(select 1 from public.seller_listing_handoffs h where h.listing_id=new.id and (h.property_id is distinct from new.property_id or h.organization_id is distinct from new.organization_id)) then raise exception 'Seller handoff property relation is immutable' using errcode='22023';end if;
 return new;
end $$;
revoke all on function private.guard_listing_property_relation() from public,anon,authenticated;
create trigger guard_listing_property_relation before insert or update of property_id,unit_id,organization_id on public.listings for each row execute function private.guard_listing_property_relation();

create function private.prepare_seller_listing(p_lead_id uuid,p_request_id uuid,p_public_title text,p_public_area text,p_property_type text,p_approval_reason text,p_seller_approved boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); org uuid; lead public.seller_leads; existing public.seller_listing_handoffs; created_property uuid; created_listing uuid;
begin
 org:=private.verified_catalog_organization();
 if caller is null or org is null then raise exception 'Verified catalog author required' using errcode='42501';end if;
 if p_request_id is null or p_seller_approved is distinct from true or p_public_title is null or length(trim(p_public_title)) not between 3 and 160 or p_public_area is null or length(trim(p_public_area)) not between 2 and 120 or p_property_type is null or p_property_type not in('house','apartment','townhouse','land','commercial') or p_approval_reason is null or length(trim(p_approval_reason)) not between 5 and 500 then raise exception 'Approved proposal and public draft details required' using errcode='22023';end if;
 select * into lead from public.seller_leads where id=p_lead_id for update;
 if lead.id is null or lead.organization_id is distinct from org then raise exception 'Seller request unavailable' using errcode='42501';end if;
 select * into existing from public.seller_listing_handoffs where seller_lead_id=lead.id;
 if existing.id is not null then
  if existing.request_id<>p_request_id or existing.approved_by<>caller or existing.public_title<>trim(p_public_title) or existing.public_area<>trim(p_public_area) or existing.property_type<>p_property_type or existing.approval_reason<>trim(p_approval_reason) then raise exception 'Proposal already handed off; use its existing draft' using errcode='P0001';end if;
  return jsonb_build_object('property_id',existing.property_id,'listing_id',existing.listing_id);
 end if;
 if lead.status<>'proposal' or lead.listing_id is not null then raise exception 'Proposal review required before handoff' using errcode='22023';end if;
 insert into public.properties(organization_id,name,area,address_text) values(org,trim(p_public_title),trim(p_public_area),lead.property_address) returning id into created_property;
 insert into public.listings(organization_id,property_id,title,area,intent,property_type,status,price_jmd,description) values(org,created_property,trim(p_public_title),trim(p_public_area),'sale',p_property_type,'draft',0,'') returning id into created_listing;
 insert into public.seller_listing_handoffs(seller_lead_id,organization_id,property_id,listing_id,request_id,approved_by,approval_reason,public_title,public_area,property_type) values(lead.id,org,created_property,created_listing,p_request_id,caller,trim(p_approval_reason),trim(p_public_title),trim(p_public_area),p_property_type);
 update public.seller_leads set listing_id=created_listing,updated_at=now() where id=lead.id;
 insert into public.seller_lead_events(seller_lead_id,actor_user_id,old_status,new_status,reason) values(lead.id,caller,'proposal','proposal','Approved proposal; listing draft prepared. '||trim(p_approval_reason));
 return jsonb_build_object('property_id',created_property,'listing_id',created_listing);
end $$;
revoke all on function private.prepare_seller_listing(uuid,uuid,text,text,text,text,boolean) from public,anon;
grant execute on function private.prepare_seller_listing(uuid,uuid,text,text,text,text,boolean) to authenticated;
create function public.prepare_seller_listing(p_lead_id uuid,p_request_id uuid,p_public_title text,p_public_area text,p_property_type text,p_approval_reason text,p_seller_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.prepare_seller_listing(p_lead_id,p_request_id,p_public_title,p_public_area,p_property_type,p_approval_reason,p_seller_approved);$$;
revoke all on function public.prepare_seller_listing(uuid,uuid,text,text,text,text,boolean) from public,anon;
grant execute on function public.prepare_seller_listing(uuid,uuid,text,text,text,text,boolean) to authenticated;

-- Publication advances the seller only when an approved linked draft is actually published.
create function private.record_seller_listing_publication() returns trigger language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); org uuid; lead public.seller_leads;
begin
 if new.status<>'published' then return new;end if;
 select l.* into lead from public.seller_leads l join public.seller_listing_handoffs h on h.seller_lead_id=l.id where h.listing_id=new.id for update of l;
 if lead.id is null then return new;end if;
 org:=private.verified_catalog_organization();
 if caller is null or org is null or org<>new.organization_id or lead.organization_id<>org then raise exception 'Verified catalog author required to publish seller draft' using errcode='42501';end if;
 if lead.status not in('proposal','listed') then raise exception 'Seller proposal is no longer active' using errcode='22023';end if;
 if lead.status='proposal' then
  update public.seller_leads set status='listed',updated_at=now() where id=lead.id;
  insert into public.seller_lead_events(seller_lead_id,actor_user_id,old_status,new_status,reason) values(lead.id,caller,'proposal','listed','Approved property listing published.');
 end if;
 return new;
end $$;
revoke all on function private.record_seller_listing_publication() from public,anon,authenticated;
create trigger record_seller_listing_publication after update of status on public.listings for each row execute function private.record_seller_listing_publication();
