create or replace function private.require_balanced_journal() returns trigger language plpgsql security definer set search_path='' as $$
declare target uuid;debits numeric;credits numeric;lines integer;
begin
 if tg_table_name='finance_journals' then target:=new.id;else target:=new.journal_id;end if;
 select count(*),coalesce(sum(debit_minor),0),coalesce(sum(credit_minor),0) into lines,debits,credits from public.finance_journal_lines where journal_id=target;
 if lines not between 2 and 200 or debits<=0 or debits<>credits then raise exception 'A journal must contain two to two hundred balanced positive lines' using errcode='23505';end if;return null;
end $$;
revoke all on function private.require_balanced_journal() from public,anon,authenticated,service_role;
