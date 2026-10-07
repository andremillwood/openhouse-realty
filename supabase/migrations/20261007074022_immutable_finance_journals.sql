-- Finance records are closed to direct writes; approved RPCs are added separately.
create function private.verified_finance_organization() returns uuid language sql stable security definer set search_path='' as $$
 select s.organization_id from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=auth.uid() and s.role in('admin','finance') and u.email_confirmed_at is not null;
$$;
revoke all on function private.verified_finance_organization() from public,anon,authenticated;
grant execute on function private.verified_finance_organization() to authenticated;
create table public.finance_accounts(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),code text not null check(length(trim(code)) between 1 and 40),name text not null check(length(trim(name)) between 2 and 120),account_class text not null check(account_class in('asset','liability','equity','income','expense')),approved_by uuid not null references auth.users(id),approval_reason text not null check(length(trim(approval_reason)) between 5 and 500),created_at timestamptz not null default now(),unique(organization_id,code)
);
create table public.finance_journals(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),request_id uuid not null,posted_by uuid not null references auth.users(id),currency text not null default 'JMD' check(currency='JMD'),memo text not null check(length(trim(memo)) between 5 and 1000),reason text not null check(length(trim(reason)) between 5 and 500),payload jsonb not null,created_transaction xid8 not null default pg_current_xact_id(),posted_at timestamptz not null default now(),unique(posted_by,request_id)
);
create index finance_journal_org_history_idx on public.finance_journals(organization_id,posted_at desc,id);
create table public.finance_journal_lines(
 id uuid primary key default gen_random_uuid(),journal_id uuid not null references public.finance_journals(id),organization_id uuid not null references public.organizations(id),line_number integer not null check(line_number between 1 and 200),account_id uuid not null references public.finance_accounts(id),property_id uuid references public.properties(id),unit_id uuid references public.units(id),debit_minor bigint not null default 0 check(debit_minor between 0 and 99999999999999),credit_minor bigint not null default 0 check(credit_minor between 0 and 99999999999999),unique(journal_id,line_number),check((debit_minor>0)<>(credit_minor>0)),check(unit_id is null or property_id is not null)
);
create index finance_lines_account_idx on public.finance_journal_lines(organization_id,account_id,journal_id);
create index finance_lines_property_idx on public.finance_journal_lines(property_id,journal_id) where property_id is not null;
create index finance_lines_unit_idx on public.finance_journal_lines(unit_id,journal_id) where unit_id is not null;
alter table public.finance_accounts enable row level security;
alter table public.finance_journals enable row level security;
alter table public.finance_journal_lines enable row level security;
revoke all on public.finance_accounts,public.finance_journals,public.finance_journal_lines from public,anon,authenticated,service_role;
grant select on public.finance_accounts,public.finance_journals,public.finance_journal_lines to authenticated,service_role;
create policy "verified finance read organization accounts" on public.finance_accounts for select to authenticated using(organization_id=(select private.verified_finance_organization()));
create policy "verified finance read organization journals" on public.finance_journals for select to authenticated using(organization_id=(select private.verified_finance_organization()));
create policy "verified finance read organization journal lines" on public.finance_journal_lines for select to authenticated using(organization_id=(select private.verified_finance_organization()));
create function private.guard_finance_immutable() returns trigger language plpgsql security definer set search_path='' as $$
begin raise exception 'Finance records are immutable; use a separately approved reversal' using errcode='23505';end $$;
revoke all on function private.guard_finance_immutable() from public,anon,authenticated,service_role;
create trigger guard_finance_immutable before update or delete on public.finance_accounts for each row execute function private.guard_finance_immutable();
create trigger guard_finance_immutable before update or delete on public.finance_journals for each row execute function private.guard_finance_immutable();
create trigger guard_finance_immutable before update or delete on public.finance_journal_lines for each row execute function private.guard_finance_immutable();
create function private.guard_finance_insert() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='finance_accounts' then
 if not exists(select 1 from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=new.approved_by and s.organization_id=new.organization_id and s.role='admin' and u.email_confirmed_at is not null) then raise exception 'Verified organization administrator approval required' using errcode='42501';end if;
 new.created_at:=statement_timestamp();
 elsif tg_table_name='finance_journals' then
 if not exists(select 1 from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=new.posted_by and s.organization_id=new.organization_id and s.role in('admin','finance') and u.email_confirmed_at is not null) then raise exception 'Verified organization finance authority required' using errcode='42501';end if;
 new.posted_at:=statement_timestamp();new.created_transaction:=pg_current_xact_id();
 else
 if not exists(select 1 from public.finance_journals j join public.finance_accounts a on a.id=new.account_id where j.id=new.journal_id and j.created_transaction=pg_current_xact_id() and j.organization_id=new.organization_id and a.organization_id=new.organization_id) then raise exception 'Journal/account organization binding required' using errcode='23505';end if;
 if new.property_id is not null and not exists(select 1 from public.properties where id=new.property_id and organization_id=new.organization_id) then raise exception 'Organization property required' using errcode='23505';end if;
 if new.unit_id is not null and not exists(select 1 from public.units where id=new.unit_id and property_id=new.property_id) then raise exception 'Unit/property binding required' using errcode='23505';end if;
 end if;return new;
end $$;
revoke all on function private.guard_finance_insert() from public,anon,authenticated,service_role;
create trigger guard_finance_insert before insert on public.finance_accounts for each row execute function private.guard_finance_insert();
create trigger guard_finance_insert before insert on public.finance_journals for each row execute function private.guard_finance_insert();
create trigger guard_finance_insert before insert on public.finance_journal_lines for each row execute function private.guard_finance_insert();
create function private.require_balanced_journal() returns trigger language plpgsql security definer set search_path='' as $$
declare target uuid;debits numeric;credits numeric;lines integer;
begin
 target:=case when tg_table_name='finance_journals' then new.id else new.journal_id end;
 select count(*),coalesce(sum(debit_minor),0),coalesce(sum(credit_minor),0) into lines,debits,credits from public.finance_journal_lines where journal_id=target;
 if lines not between 2 and 200 or debits<=0 or debits<>credits then raise exception 'A journal must contain two to two hundred balanced positive lines' using errcode='23505';end if;return null;
end $$;
revoke all on function private.require_balanced_journal() from public,anon,authenticated,service_role;
create constraint trigger require_balanced_journal after insert on public.finance_journals deferrable initially deferred for each row execute function private.require_balanced_journal();
create constraint trigger require_balanced_journal after insert on public.finance_journal_lines deferrable initially deferred for each row execute function private.require_balanced_journal();
