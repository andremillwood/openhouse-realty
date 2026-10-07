-- Invoker view retains independent staff policies on drafts/releases and participant event RLS.
create view public.pending_lease_review_questions with(security_invoker=true) as
select r.id as release_id,r.organization_id,r.application_id,r.draft_id,r.draft_version,
 a.title_snapshot,latest.version as review_version,latest.message,latest.created_at as asked_at
from public.rental_lease_summary_releases r
join public.rental_lease_drafts d on d.id=r.draft_id and d.application_id=r.application_id and d.organization_id=r.organization_id
join public.rental_applications a on a.id=r.application_id and a.organization_id=r.organization_id
join lateral (
 select e.version,e.action,e.message,e.created_at from public.rental_lease_review_events e
 where e.release_id=r.id order by e.version desc limit 1
) latest on true
where latest.action='question' and d.state='prepared' and a.status='approved' and a.version=d.application_version
and exists(select 1 from public.rental_unit_reservations reservation where reservation.id=d.reservation_id and reservation.application_id=a.id and reservation.organization_id=r.organization_id and reservation.state='held');
revoke all on public.pending_lease_review_questions from public,anon,authenticated,service_role;
grant select on public.pending_lease_review_questions to authenticated;
