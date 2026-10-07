alter table public.properties add column management_revision integer not null default 1;
alter table public.units add column management_revision integer not null default 1;
alter table public.listings add column management_revision integer not null default 1;
create table public.managed_inventory_events (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,
 action text not null,target_id uuid,expected_revision integer not null,payload jsonb not null,result jsonb not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index managed_inventory_events_org_idx on public.managed_inventory_events(organization_id,created_at desc);
alter table public.managed_inventory_events enable row level security;
revoke all on public.managed_inventory_events from public,anon,authenticated;
grant select on public.managed_inventory_events to authenticated;
grant select,insert on public.managed_inventory_events to service_role;
create policy "verified staff read private managed inventory audit" on public.managed_inventory_events for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()));

create function private.author_managed_inventory(p_request_id uuid,p_action text,p_target_id uuid,p_expected_revision integer,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();existing public.managed_inventory_events;property public.properties;unit public.units;listing public.listings;result jsonb;name_value text;area_value text;address_value text;label_value text;bed numeric;bath numeric;parking integer;floor_value integer;size_value integer;new_unit uuid;
begin
 if org is null then raise exception 'Verified inventory staff required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('property_create','property_update','unit_create','unit_update','listing_link') or p_expected_revision is null or p_expected_revision<0 or p_expected_revision>=2147483647 or p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>5000 then raise exception 'Invalid managed inventory request' using errcode='22023';end if;
 if p_action='listing_link' and org is distinct from private.verified_catalog_organization() then raise exception 'Catalog author required for listing linkage' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,116));
 select * into existing from public.managed_inventory_events where actor_user_id=caller and request_id=p_request_id;
 if existing.id is not null then if existing.organization_id<>org or existing.action<>p_action or existing.target_id is distinct from p_target_id or existing.expected_revision<>p_expected_revision or existing.payload<>p_payload then raise exception 'Request ID already used' using errcode='22023';end if;return existing.result;end if;
 if p_action in('property_create','property_update') then
  if p_payload-array['name','area','address_text']::text[]<>'{}'::jsonb or jsonb_typeof(p_payload->'name')<>'string' or jsonb_typeof(p_payload->'area')<>'string' or jsonb_typeof(p_payload->'address_text')<>'string' then raise exception 'Invalid property fields' using errcode='22023';end if;
  name_value:=trim(p_payload->>'name');area_value:=trim(p_payload->>'area');address_value:=trim(p_payload->>'address_text');
  if name_value is null or length(name_value) not between 2 and 160 or area_value is null or length(area_value) not between 2 and 120 or address_value is null or length(address_value) not between 5 and 500 then raise exception 'Property name, area and private address required' using errcode='22023';end if;
  if p_action='property_create' then
   if p_target_id is not null or p_expected_revision<>0 then raise exception 'New property requires no existing target' using errcode='22023';end if;
   insert into public.properties(organization_id,name,area,address_text) values(org,name_value,area_value,address_value) returning * into property;
  else
   select * into property from public.properties where id=p_target_id and organization_id=org for update;
   if property.id is null then raise exception 'Property unavailable' using errcode='42501';end if;
   if property.management_revision<>p_expected_revision then raise exception 'Property changed; refresh' using errcode='40001';end if;
   perform 1 from public.units where property_id=property.id order by id for update;
   if exists(select 1 from public.rental_unit_reservations r join public.units u on u.id=r.unit_id where u.property_id=property.id and r.state in('held','converted')) then raise exception 'Reserved/occupied property requires its tenancy change workflow' using errcode='22023';end if;
   update public.properties set name=name_value,area=area_value,address_text=address_value,management_revision=management_revision+1 where id=property.id returning * into property;
  end if;
  result:=jsonb_build_object('property_id',property.id,'revision',property.management_revision);
 elsif p_action in('unit_create','unit_update') then
  if p_payload-array['unit_label','bedrooms','bathrooms','parking_spaces','floor','size_sq_ft']::text[]<>'{}'::jsonb or jsonb_typeof(p_payload->'unit_label') is distinct from 'string' or jsonb_typeof(p_payload->'bedrooms') is distinct from 'number' or jsonb_typeof(p_payload->'bathrooms') is distinct from 'number' or jsonb_typeof(p_payload->'parking_spaces') is distinct from 'number' then raise exception 'Invalid unit fields' using errcode='22023';end if;
  label_value:=trim(p_payload->>'unit_label');bed:=(p_payload->>'bedrooms')::numeric;bath:=(p_payload->>'bathrooms')::numeric;parking:=(p_payload->>'parking_spaces')::integer;
  floor_value:=(p_payload->>'floor')::integer;size_value:=(p_payload->>'size_sq_ft')::integer;
  if label_value is null or length(label_value) not between 1 and 80 or bed not between 0 and 50 or mod(bed,0.5)<>0 or bath not between 0 and 50 or mod(bath,0.5)<>0 or parking not between 0 and 100 or (p_payload->>'parking_spaces')::numeric<>parking or (floor_value is not null and (floor_value not between -10 and 200 or (p_payload->>'floor')::numeric<>floor_value)) or (size_value is not null and (size_value not between 1 and 1000000 or (p_payload->>'size_sq_ft')::numeric<>size_value)) then raise exception 'Invalid unit dimensions or label' using errcode='22023';end if;
  if p_action='unit_create' then select * into property from public.properties where id=p_target_id and organization_id=org for update;
  else select * into unit from public.units where id=p_target_id;select * into property from public.properties where id=unit.property_id and organization_id=org for update;end if;
  if property.id is null then raise exception 'Private property access required' using errcode='42501';end if;
  if p_action='unit_create' then
   if property.management_revision<>p_expected_revision then raise exception 'Property changed; refresh' using errcode='40001';end if;
   insert into public.units(property_id,unit_label,bedrooms,bathrooms,parking_spaces,floor,size_sq_ft) values(property.id,label_value,bed,bath,parking,floor_value,size_value) returning * into unit;
  else
   select * into unit from public.units where id=p_target_id for update;
   if unit.management_revision<>p_expected_revision then raise exception 'Unit changed; refresh' using errcode='40001';end if;
   if exists(select 1 from public.rental_unit_reservations where unit_id=unit.id and state in('held','converted')) then raise exception 'Reserved/occupied unit requires its tenancy change workflow' using errcode='22023';end if;
   update public.units set unit_label=label_value,bedrooms=bed,bathrooms=bath,parking_spaces=parking,floor=floor_value,size_sq_ft=size_value,management_revision=management_revision+1 where id=unit.id returning * into unit;
  end if;
  result:=jsonb_build_object('property_id',property.id,'unit_id',unit.id,'revision',unit.management_revision);
 else
  if p_payload-array['unit_id']::text[]<>'{}'::jsonb or not p_payload ? 'unit_id' then raise exception 'Invalid unit linkage fields' using errcode='22023';end if;
  new_unit:=(p_payload->>'unit_id')::uuid;
  select * into listing from public.listings where id=p_target_id and organization_id=org for update;
  if listing.id is null then raise exception 'Listing unavailable' using errcode='42501';end if;
  if listing.management_revision<>p_expected_revision then raise exception 'Listing linkage changed; refresh' using errcode='40001';end if;
  if exists(select 1 from public.rental_unit_reservations where state in('held','converted') and (listing_id=listing.id or unit_id=new_unit)) then raise exception 'Reserved/occupied unit linkage is protected' using errcode='22023';end if;
  if new_unit is not null then
   select * into unit from public.units where id=new_unit;
   select * into property from public.properties where id=unit.property_id and organization_id=org;
   if property.id is null then raise exception 'Managed unit unavailable' using errcode='42501';end if;
   update public.listings set property_id=property.id,unit_id=unit.id,management_revision=management_revision+1,updated_at=now() where id=listing.id returning * into listing;
  else update public.listings set unit_id=null,management_revision=management_revision+1,updated_at=now() where id=listing.id returning * into listing;end if;
  result:=jsonb_build_object('listing_id',listing.id,'property_id',listing.property_id,'unit_id',listing.unit_id,'revision',listing.management_revision);
 end if;
 insert into public.managed_inventory_events(organization_id,actor_user_id,request_id,action,target_id,expected_revision,payload,result) values(org,caller,p_request_id,p_action,p_target_id,p_expected_revision,p_payload,result);
 return result;
end $$;
revoke all on function private.author_managed_inventory(uuid,text,uuid,integer,jsonb) from public,anon;
grant execute on function private.author_managed_inventory(uuid,text,uuid,integer,jsonb) to authenticated;
create function public.author_managed_inventory(p_request_id uuid,p_action text,p_target_id uuid,p_expected_revision integer,p_payload jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.author_managed_inventory(p_request_id,p_action,p_target_id,p_expected_revision,p_payload);$$;
revoke all on function public.author_managed_inventory(uuid,text,uuid,integer,jsonb) from public,anon;
grant execute on function public.author_managed_inventory(uuid,text,uuid,integer,jsonb) to authenticated;

-- Serialize managed inventory changes with approval/duplicate-listing holds.
create or replace function private.approve_rental_application(p_application_id uuid,p_request_id uuid,p_expected_version integer,p_policy_version integer,p_reason text,p_evidence_reference text,p_eligibility_checked boolean,p_availability_checked boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();application public.rental_applications;policy public.rental_approval_policies;listing public.listings;existing public.rental_approval_decisions;decision uuid;role_name text;documents jsonb;cosigners jsonb;
begin
 if org is null then raise exception 'Verified organization reviewer required' using errcode='42501';end if;
 if p_request_id is null or p_expected_version is null or p_expected_version<1 or p_expected_version>=2147483647 or p_policy_version is null or p_policy_version<1 or p_reason is null or length(trim(p_reason)) not between 5 and 2000 or p_evidence_reference is null or length(trim(p_evidence_reference)) not between 5 and 500 or p_eligibility_checked is distinct from true or p_availability_checked is distinct from true then raise exception 'Completed business checks and shared decision reason required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock_shared(pg_catalog.hashtextextended(org::text,115));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,116));
 select * into application from public.rental_applications where id=p_application_id for update;
 if application.id is null or application.organization_id<>org or application.user_id=caller or exists(select 1 from public.application_cosigners where application_id=application.id and recipient_user_id=caller and state='accepted') then raise exception 'Independent organization approver required' using errcode='42501';end if;
 select * into existing from public.rental_approval_decisions where application_id=application.id and approved_by=caller and request_id=p_request_id;
 if existing.id is not null then if existing.application_version<>p_expected_version+1 or existing.reason<>trim(p_reason) or existing.evidence_reference<>trim(p_evidence_reference) or not exists(select 1 from public.rental_approval_policies where id=existing.policy_id and version=p_policy_version) then raise exception 'Request ID already used' using errcode='22023';end if;return jsonb_build_object('status',application.status,'version',application.version);end if;
 select * into policy from public.rental_approval_policies where organization_id=org order by version desc limit 1;
 if policy.id is null then raise exception 'Approved business policy not configured' using errcode='22023';end if;
 if policy.version<>p_policy_version or application.version<>p_expected_version then raise exception 'Application or policy changed; refresh' using errcode='40001';end if;
 select role into role_name from public.staff_accounts where user_id=caller;
 if not role_name=any(policy.approver_roles) then raise exception 'Role not authorized by business approval policy' using errcode='42501';end if;
 if application.status<>'under_review' or application.desired_move_in<(now() at time zone 'America/Jamaica')::date then raise exception 'Application review or move-in date incomplete' using errcode='22023';end if;
 if exists(select 1 from unnest(policy.required_document_kinds) kind where not exists(select 1 from public.application_documents d join public.application_document_reviews r on r.document_id=d.id where d.application_id=application.id and d.organization_id=org and d.kind=kind and d.state='uploaded' and r.status='verified' and r.file_sha256=d.sha256 and r.reviewer_user_id<>application.user_id and not exists(select 1 from public.application_cosigners c where c.application_id=application.id and c.recipient_user_id=r.reviewer_user_id and c.state='accepted'))) or exists(select 1 from public.application_documents d join public.application_document_reviews r on r.document_id=d.id where d.application_id=application.id and d.state='uploaded' and r.status in('needs_info','not_accepted')) then raise exception 'Required document evidence not verified or issues remain open' using errcode='22023';end if;
 if exists(select 1 from public.application_cosigners where application_id=application.id and state='pending' and expires_at>now()) or (select count(*) from public.application_cosigners c join auth.users u on u.id=c.recipient_user_id where c.application_id=application.id and c.state='accepted' and c.consent_version=1 and u.email_confirmed_at is not null)<policy.required_cosigners then raise exception 'Required co-signer review consent incomplete' using errcode='22023';end if;
 select * into listing from public.listings where id=application.listing_id for update;
 if listing.organization_id is distinct from org or listing.intent<>'rent' or listing.status<>'published' or listing.price_jmd<>application.rent_jmd_snapshot or listing.unit_id is null then raise exception 'Published rental terms and managed unit required' using errcode='22023';end if;
 perform 1 from public.units u join public.properties p on p.id=u.property_id where u.id=listing.unit_id and p.id=listing.property_id and p.organization_id=org for update of u;
 if not found then raise exception 'Managed unit unavailable' using errcode='22023';end if;
 if exists(select 1 from public.rental_unit_reservations where unit_id=listing.unit_id and state in('held','converted')) then raise exception 'Unit already reserved or occupied' using errcode='23505';end if;
 select coalesce(jsonb_agg(jsonb_build_object('document_id',d.id,'sha256',d.sha256,'review_version',r.version,'reviewer',r.reviewer_user_id)), '[]'::jsonb) into documents from public.application_documents d join public.application_document_reviews r on r.document_id=d.id where d.application_id=application.id and d.state='uploaded' and r.status='verified' and r.file_sha256=d.sha256;
 select coalesce(jsonb_agg(jsonb_build_object('cosigner_id',id,'recipient_user_id',recipient_user_id,'version',version,'consented_at',consented_at,'consent_version',consent_version)), '[]'::jsonb) into cosigners from public.application_cosigners where application_id=application.id and state='accepted';
 insert into public.rental_approval_decisions(application_id,organization_id,policy_id,listing_id,unit_id,approved_by,request_id,application_version,reason,evidence_reference,document_snapshot,cosigner_snapshot) values(application.id,org,policy.id,listing.id,listing.unit_id,caller,p_request_id,application.version+1,trim(p_reason),trim(p_evidence_reference),documents,cosigners) returning id into decision;
 insert into public.rental_unit_reservations(decision_id,application_id,organization_id,listing_id,unit_id) values(decision,application.id,org,listing.id,listing.unit_id);
 update public.listings set status=case when id=listing.id then 'under_offer' else 'paused' end,updated_at=now() where unit_id=listing.unit_id and organization_id=org and status='published';
 update public.rental_applications set status='approved',version=version+1,updated_at=now() where id=application.id;
 perform private.record_application_event(application.id,p_request_id,'approved',application.status,trim(p_reason));
 return jsonb_build_object('status','approved','version',application.version+1);
end $$;

-- Public catalog edits cannot bypass the audited property/unit linkage function.
revoke insert,update on public.listings from authenticated;
grant insert(id,organization_id,title,area,intent,property_type,status,price_jmd,bedrooms,bathrooms,parking_spaces,floor,size_sq_ft,balcony,furnished,modern_interior,description,photo_url,approximate_latitude,approximate_longitude,location_label,published_at,updated_at) on public.listings to authenticated;
grant update(organization_id,title,area,intent,property_type,status,price_jmd,bedrooms,bathrooms,parking_spaces,floor,size_sq_ft,balcony,furnished,modern_interior,description,photo_url,approximate_latitude,approximate_longitude,location_label,published_at,updated_at) on public.listings to authenticated;
