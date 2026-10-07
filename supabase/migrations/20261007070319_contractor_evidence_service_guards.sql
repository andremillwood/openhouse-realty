grant execute on function private.contractor_evidence_mutable(uuid,uuid) to service_role;
create function private.guard_report_evidence_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.contractor_completion_reports r join public.contractor_evidence e on e.offer_id=r.offer_id and e.organization_id=r.organization_id and e.user_id=r.contractor_user_id where r.id=new.report_id and e.id=new.evidence_id and e.state='uploaded') then raise exception 'Uploaded evidence must match report assignment and identity' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_report_evidence_binding() from public,anon,authenticated;
create trigger guard_report_evidence_binding before insert on public.contractor_report_evidence for each row execute function private.guard_report_evidence_binding();
