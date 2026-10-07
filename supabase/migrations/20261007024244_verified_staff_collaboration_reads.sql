create function private.verified_enquiry_staff_organization() returns uuid
language sql stable security definer set search_path='' as $$
 select s.organization_id from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=auth.uid() and u.email_confirmed_at is not null and s.role in ('admin','realtor','manager');
$$;
revoke all on function private.verified_enquiry_staff_organization() from public,anon;
grant execute on function private.verified_enquiry_staff_organization() to authenticated;
alter policy "staff read organization assignments" on public.enquiry_assignments using (organization_id=(select private.verified_enquiry_staff_organization()));
alter policy "staff read organization notes" on public.enquiry_staff_notes using (organization_id=(select private.verified_enquiry_staff_organization()));
alter policy "staff read organization assignment history" on public.enquiry_assignment_events using (organization_id=(select private.verified_enquiry_staff_organization()));
