create function private.guard_invoice_evidence_state() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.state='uploaded' and row(new.sha256,new.actual_size,new.uploaded_at) is distinct from row(old.sha256,old.actual_size,old.uploaded_at) then
  raise exception 'Certified invoice bytes are immutable' using errcode='23505';
 end if;
 if new.state is distinct from old.state and not (
  (old.state='reserved' and new.state in('uploaded','withdrawn','expired')) or
  (old.state='uploaded' and new.state='withdrawn')
 ) then raise exception 'Invoice evidence transition unavailable' using errcode='23505';end if;
 if old.state in('withdrawn','expired') and row(new.sha256,new.actual_size,new.uploaded_at,new.withdrawn_at) is distinct from row(old.sha256,old.actual_size,old.uploaded_at,old.withdrawn_at) then
  raise exception 'Terminal invoice evidence is immutable' using errcode='23505';
 end if;
 if old.state='reserved' and new.state<>'uploaded' and row(new.sha256,new.actual_size,new.uploaded_at) is distinct from row(old.sha256,old.actual_size,old.uploaded_at) then
  raise exception 'Certification requires uploaded state' using errcode='23505';
 end if;
 return new;
end $$;
revoke all on function private.guard_invoice_evidence_state() from public,anon,authenticated,service_role;
create trigger guard_invoice_evidence_state before update on public.vendor_invoice_evidence for each row execute function private.guard_invoice_evidence_state();
