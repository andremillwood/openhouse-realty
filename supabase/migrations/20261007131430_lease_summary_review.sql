-- Shared review history is separate from legal acceptance, signing and tenancy authority.
create function private.lease_summary_review_role(p_release_id uuid) returns text language sql stable security definer set search_path='' as $$
 select case when a.user_id=auth.uid() then 'applicant'
 when r.organization_id=private.verified_enquiry_staff_organization()
 and not exists(select 1 from public.application_cosigners c where c.application_id=a.id and c.recipient_user_id=auth.uid() and c.state='accepted') then 'staff' else null end
 from public.rental_lease_summary_releases r
 join public.rental_lease_drafts d on d.id=r.draft_id and d.application_id=r.application_id and d.organization_id=r.organization_id
 join public.rental_applications a on a.id=r.application_id and a.organization_id=r.organization_id
 where r.id=p_release_id and exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null);
$$;
revoke all on function private.lease_summary_review_role(uuid) from public,anon,authenticated,service_role;
grant execute on function private.lease_summary_review_role(uuid) to authenticated;
create table public.rental_lease_review_events (
 id uuid primary key default gen_random_uuid(),release_id uuid not null references public.rental_lease_summary_releases(id),
 actor_user_id uuid not null references auth.users(id),request_id uuid not null,
 version integer not null check(version between 1 and 2147483646),
 action text not null check(action in('reviewed','question','answer')),
 actor_kind text not null check(actor_kind in('applicant','staff')),
 message text not null check((action='reviewed' and message='') or (action in('question','answer') and length(message) between 10 and 2000)),
 created_at timestamptz not null default statement_timestamp(),
 unique(release_id,version),unique(actor_user_id,request_id),
 check((action='answer' and actor_kind='staff') or (action in('reviewed','question') and actor_kind='applicant'))
);
alter table public.rental_lease_review_events enable row level security;
revoke all on public.rental_lease_review_events from public,anon,authenticated,service_role;
grant select(id,release_id,version,action,actor_kind,message,created_at) on public.rental_lease_review_events to authenticated;
create policy "verified summary participants read shared review events" on public.rental_lease_review_events for select to authenticated using(private.lease_summary_review_role(release_id) is not null);
create trigger immutable_lease_review_events before update or delete on public.rental_lease_review_events for each row execute function private.guard_finance_immutable();
create function private.review_rental_lease_summary(p_release_id uuid,p_request_id uuid,p_expected_version integer,p_action text,p_message text,p_review_only_acknowledged boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();r public.rental_lease_summary_releases;a public.rental_applications;d public.rental_lease_drafts;prior public.rental_lease_review_events;latest public.rental_lease_review_events;kind text;verified_email text;created uuid;current_version integer;
begin
 kind:=private.lease_summary_review_role(p_release_id);
 if kind is null then raise exception 'Verified summary participant required' using errcode='42501';end if;
 if p_request_id is null or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483646 or p_action is null or p_action not in('reviewed','question','answer') or p_message is null or p_review_only_acknowledged is distinct from true or (p_action='reviewed' and trim(p_message)<>'') or (p_action in('question','answer') and length(trim(p_message)) not between 10 and 2000) then raise exception 'Valid review-only response required' using errcode='22023';end if;
 if (kind='staff' and p_action<>'answer') or (kind='applicant' and p_action='answer') then raise exception 'Response role mismatch' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,167));
 select * into r from public.rental_lease_summary_releases where id=p_release_id;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(r.organization_id::text,119));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(r.organization_id::text,116));
 select * into a from public.rental_applications where id=r.application_id for update;
 select email into verified_email from auth.users where id=caller and email_confirmed_at is not null for share;
 if verified_email is null or private.lease_summary_review_role(r.id) is distinct from kind then raise exception 'Participant authority changed' using errcode='42501';end if;
 select * into prior from public.rental_lease_review_events where actor_user_id=caller and request_id=p_request_id;
 if prior.id is not null then
  if prior.release_id<>r.id or prior.version<>p_expected_version+1 or prior.action<>p_action or prior.message<>trim(p_message) then raise exception 'Request reference already used' using errcode='22023';end if;
  return jsonb_build_object('id',prior.id,'release_id',r.id,'version',prior.version,'action',prior.action);
 end if;
 select * into d from public.rental_lease_drafts where id=r.draft_id for share;
 if d.state<>'prepared' or a.status<>'approved' or a.version<>d.application_version or not exists(select 1 from public.rental_unit_reservations where id=d.reservation_id and application_id=a.id and state='held') then raise exception 'Summary no longer current' using errcode='40001';end if;
 if kind='applicant' and (lower(verified_email)<>lower(a.contact_email) or lower(verified_email) is distinct from lower(d.snapshot->'applicant'->>'email')) then raise exception 'Applicant contact review required' using errcode='22023';end if;
 select * into latest from public.rental_lease_review_events where release_id=r.id order by version desc limit 1;
 current_version:=coalesce(latest.version,0);
 if current_version<>p_expected_version then raise exception 'Review changed; refresh' using errcode='40001';end if;
 if p_action='answer' and latest.action is distinct from 'question' then raise exception 'Current applicant question required' using errcode='23505';end if;
 if kind='applicant' and latest.action='question' then raise exception 'Question is awaiting a reply' using errcode='23505';end if;
 if p_action='reviewed' and latest.action='reviewed' then raise exception 'This review is already recorded' using errcode='23505';end if;
 if (select count(*) from public.rental_lease_review_events where actor_user_id=caller and created_at>statement_timestamp()-interval '1 day')>=50 then raise exception 'Daily review response limit reached' using errcode='P0001';end if;
 insert into public.rental_lease_review_events(release_id,actor_user_id,request_id,version,action,actor_kind,message) values(r.id,caller,p_request_id,current_version+1,p_action,kind,trim(p_message)) returning id into created;
 return jsonb_build_object('id',created,'release_id',r.id,'version',current_version+1,'action',p_action);
end $$;
revoke all on function private.review_rental_lease_summary(uuid,uuid,integer,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.review_rental_lease_summary(uuid,uuid,integer,text,text,boolean) to authenticated;
create function public.review_rental_lease_summary(p_release_id uuid,p_request_id uuid,p_expected_version integer,p_action text,p_message text,p_review_only_acknowledged boolean) returns jsonb language sql security invoker set search_path='' as $$select private.review_rental_lease_summary(p_release_id,p_request_id,p_expected_version,p_action,p_message,p_review_only_acknowledged);$$;
revoke all on function public.review_rental_lease_summary(uuid,uuid,integer,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.review_rental_lease_summary(uuid,uuid,integer,text,text,boolean) to authenticated;
create function private.lease_summary_review_history(p_application_id uuid,p_draft_id uuid,p_page integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r public.rental_lease_summary_releases;d public.rental_lease_drafts;a public.rental_applications;kind text;total bigint;current_version integer;latest_action text;items jsonb;is_current boolean;
begin
 select * into r from public.rental_lease_summary_releases where application_id=p_application_id and draft_id=p_draft_id;
 kind:=private.lease_summary_review_role(r.id);
 if kind is null then raise exception 'Verified summary participant required' using errcode='42501';end if;
 if p_page is null or p_page not between 1 and 100000 then raise exception 'Valid history page required' using errcode='22023';end if;
 select * into d from public.rental_lease_drafts where id=r.draft_id;
 select * into a from public.rental_applications where id=r.application_id;
 is_current:=d.state='prepared' and a.status='approved' and a.version=d.application_version and exists(select 1 from public.rental_unit_reservations where id=d.reservation_id and application_id=a.id and state='held');
 select count(*) into total from public.rental_lease_review_events where release_id=r.id;
 select version,action into current_version,latest_action from public.rental_lease_review_events where release_id=r.id order by version desc limit 1;
 select coalesce(jsonb_agg(item order by version desc),'[]'::jsonb) into items from (
  select version,jsonb_build_object('id',id,'version',version,'action',action,'actor_kind',actor_kind,'message',message,'created_at',created_at) as item
  from public.rental_lease_review_events where release_id=r.id order by version desc limit 25 offset (p_page-1)*25
 ) rows;
 return jsonb_build_object('release_id',r.id,'role',kind,'current',is_current,'revision',coalesce(current_version,0),'latest_action',latest_action,'total',total,'items',items,
 'summary',jsonb_build_object('id',d.id,'version',d.version,'state',d.state,'starts_on',d.starts_on,'ends_on',d.ends_on,'billing_day',d.billing_day,'rent_minor',d.rent_minor::text,'deposit_minor',d.deposit_minor::text,'property_name',d.snapshot->'property'->>'name','unit_label',d.snapshot->'unit'->>'label','template_title',d.snapshot->'template'->>'title','released_at',r.created_at));
end $$;
revoke all on function private.lease_summary_review_history(uuid,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function private.lease_summary_review_history(uuid,uuid,integer) to authenticated;
create function public.lease_summary_review_history(p_application_id uuid,p_draft_id uuid,p_page integer default 1) returns jsonb language sql stable security invoker set search_path='' as $$select private.lease_summary_review_history(p_application_id,p_draft_id,p_page);$$;
revoke all on function public.lease_summary_review_history(uuid,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.lease_summary_review_history(uuid,uuid,integer) to authenticated;
