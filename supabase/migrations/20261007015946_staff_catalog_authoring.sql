-- Membership is administered outside browser-accessible CRUD.
alter table public.staff_accounts add column organization_id uuid references public.organizations(id);
create index staff_accounts_organization_idx on public.staff_accounts(organization_id);
alter table public.listings add column organization_id uuid references public.organizations(id), add column photo_url text;
alter table public.realtor_profiles add column organization_id uuid references public.organizations(id);
create index listings_organization_idx on public.listings(organization_id);
create index realtor_profiles_organization_idx on public.realtor_profiles(organization_id);
alter table public.listings add constraint listings_publication_ready check (status <> 'published' or (organization_id is not null and length(trim(title)) >= 3 and description is not null and length(trim(description)) >= 20 and photo_url is not null and photo_url like 'https://%'));
alter table public.realtor_profiles add constraint realtor_publication_ready check (not is_published or (organization_id is not null and length(trim(display_name)) >= 2 and length(trim(bio)) >= 20 and cardinality(service_areas) > 0 and cardinality(supported_intents) > 0));
grant select on public.organizations to authenticated;
create policy "staff read own organization" on public.organizations for select to authenticated using (id in (select organization_id from public.staff_accounts where user_id = (select auth.uid())));
grant insert, update on public.listings to authenticated;
create policy "catalog staff read own listings" on public.listings for select to authenticated using (organization_id in (select organization_id from public.staff_accounts where user_id = (select auth.uid()) and role in ('admin','realtor')));
create policy "catalog staff create own listings" on public.listings for insert to authenticated with check (organization_id in (select organization_id from public.staff_accounts where user_id = (select auth.uid()) and role in ('admin','realtor')));
create policy "catalog staff update own listings" on public.listings for update to authenticated using (organization_id in (select organization_id from public.staff_accounts where user_id = (select auth.uid()) and role in ('admin','realtor'))) with check (organization_id in (select organization_id from public.staff_accounts where user_id = (select auth.uid()) and role in ('admin','realtor')));
grant insert, update on public.realtor_profiles to authenticated;
create policy "catalog staff read own realtor_profiles" on public.realtor_profiles for select to authenticated using (organization_id in (select organization_id from public.staff_accounts where user_id = (select auth.uid()) and role in ('admin','realtor')));
create policy "catalog staff create own realtor_profiles" on public.realtor_profiles for insert to authenticated with check (organization_id in (select organization_id from public.staff_accounts where user_id = (select auth.uid()) and role in ('admin','realtor')));
create policy "catalog staff update own realtor_profiles" on public.realtor_profiles for update to authenticated using (organization_id in (select organization_id from public.staff_accounts where user_id = (select auth.uid()) and role in ('admin','realtor'))) with check (organization_id in (select organization_id from public.staff_accounts where user_id = (select auth.uid()) and role in ('admin','realtor')));
