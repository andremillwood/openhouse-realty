-- Isolated test database only. Not a production migration.
create role anon;create role authenticated;create role service_role;
create schema auth;create schema private;
create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema auth,private,public to authenticated;
grant execute on function auth.uid() to authenticated;
create table public.organizations(id uuid primary key,name text);
create table public.staff_accounts(user_id uuid primary key references auth.users(id),organization_id uuid references public.organizations(id),role text);
create table public.properties(id uuid primary key,organization_id uuid references public.organizations(id),name text);
create table public.units(id uuid primary key,property_id uuid references public.properties(id),unit_label text);
create function private.verified_staff_admin_organization() returns uuid language sql stable security definer set search_path='' as $$select s.organization_id from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=auth.uid() and s.role='admin' and u.email_confirmed_at is not null$$;
revoke all on function private.verified_staff_admin_organization() from public;
grant execute on function private.verified_staff_admin_organization() to authenticated;
