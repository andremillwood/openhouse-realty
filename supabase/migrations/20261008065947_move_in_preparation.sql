-- Operational preparation is not tenancy, signature or payment authority.
create table public.rental_move_in_preparation_events(
 id uuid primary key default gen_random_uuid(),draft_id uuid not null references public.rental_lease_drafts(id),organization_id uuid not null references public.organizations(id),
 kind text not null check(kind in('unit_readiness','utilities','access_preparation')),version integer not null check(version>0),
 state text not null check(state in('pending','ready','blocked')),evidence_reference text not null check(length(evidence_reference)<=500 and (state<>'ready' or length(evidence_reference)>=5)),
 reason text not null check(length(reason) between 5 and 500),actor_user_id uuid not null references auth.users(id),request_id uuid not null,
 created_at timestamptz not null default statement_timestamp(),unique(draft_id,kind,version),unique(actor_user_id,request_id)
);
alter table public.rental_move_in_preparation_events enable row level security;
revoke all on public.rental_move_in_preparation_events from public,anon,authenticated,service_role;
grant select on public.rental_move_in_preparation_events to authenticated;
create policy "independent staff read move-in preparation" on public.rental_move_in_preparation_events for select to authenticated using(
 organization_id=(select private.verified_enquiry_staff_organization()) and exists(select 1 from public.rental_lease_drafts d where d.id=draft_id and d.organization_id=rental_move_in_preparation_events.organization_id)
);
create trigger immutable_move_in_preparation before update or delete on public.rental_move_in_preparation_events for each row execute function private.guard_finance_immutable();
create function private.record_move_in_preparation(p_draft_id uuid,p_expected_draft_version integer,p_kind text,p_expected_version integer,p_state text,p_evidence_reference text,p_reason text,p_request_id uuid,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();d public.rental_lease_drafts;a public.rental_applications;r public.rental_move_in_preparation_events;current_version integer;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified independent staff required' using errcode='42501';end if;
 if p_draft_id is null or p_request_id is null or p_expected_draft_version is null or p_expected_draft_version not between 1 and 2147483645 or p_expected_version is null or p_expected_version not between 0 and 2147483645 or p_kind is null or p_kind not in('unit_readiness','utilities','access_preparation') or p_state is null or p_state not in('pending','ready','blocked') or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_evidence_reference is null or length(trim(p_evidence_reference))>500 or (p_state='ready' and length(trim(p_evidence_reference))<5) or p_approved is distinct from true then raise exception 'Approved explained preparation and readiness evidence required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 perform 1 from auth.users where id=caller and email_confirmed_at is not null for share;
 if not found or private.verified_enquiry_staff_organization() is distinct from org then raise exception 'Staff authority changed' using errcode='42501';end if;
 select * into d from public.rental_lease_drafts where id=p_draft_id and organization_id=org;
 if d.id is null then raise exception 'Organization draft required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,116));
 select * into a from public.rental_applications where id=d.application_id for update;
 if a.id is null or a.organization_id<>org or a.user_id=caller or exists(select 1 from public.application_cosigners where application_id=a.id and recipient_user_id=caller and state='accepted') then raise exception 'Independent staff required' using errcode='42501';end if;
 select * into d from public.rental_lease_drafts where id=p_draft_id for share;
 select * into r from public.rental_move_in_preparation_events where actor_user_id=caller and request_id=p_request_id;
 if r.id is not null then
  if r.draft_id<>d.id or d.version<>p_expected_draft_version or r.kind<>p_kind or r.version<>p_expected_version+1 or r.state<>p_state or r.reason<>trim(p_reason) or r.evidence_reference<>trim(p_evidence_reference) then raise exception 'Request reference already used' using errcode='22023';end if;
  return jsonb_build_object('id',r.id,'draft_id',d.id,'kind',r.kind,'version',r.version,'state',r.state);
 end if;
 if d.version<>p_expected_draft_version or d.state<>'prepared' or a.status<>'approved' or d.application_version<>a.version or not exists(select 1 from public.rental_unit_reservations where id=d.reservation_id and application_id=a.id and organization_id=org and state='held') then raise exception 'Current approval, draft and reservation required' using errcode='40001';end if;
 select coalesce(max(version),0) into current_version from public.rental_move_in_preparation_events where draft_id=d.id and kind=p_kind;
 if current_version<>p_expected_version then raise exception 'Preparation changed; refresh' using errcode='40001';end if;
 insert into public.rental_move_in_preparation_events(draft_id,organization_id,kind,version,state,evidence_reference,reason,actor_user_id,request_id) values(d.id,org,p_kind,current_version+1,p_state,trim(p_evidence_reference),trim(p_reason),caller,p_request_id) returning id into created;
 return jsonb_build_object('id',created,'draft_id',d.id,'kind',p_kind,'version',current_version+1,'state',p_state);
end $$;
revoke all on function private.record_move_in_preparation(uuid,integer,text,integer,text,text,text,uuid,boolean) from public,anon,authenticated,service_role;
grant execute on function private.record_move_in_preparation(uuid,integer,text,integer,text,text,text,uuid,boolean) to authenticated;
create function public.record_move_in_preparation(p_draft_id uuid,p_expected_draft_version integer,p_kind text,p_expected_version integer,p_state text,p_evidence_reference text,p_reason text,p_request_id uuid,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.record_move_in_preparation(p_draft_id,p_expected_draft_version,p_kind,p_expected_version,p_state,p_evidence_reference,p_reason,p_request_id,p_approved);$$;
revoke all on function public.record_move_in_preparation(uuid,integer,text,integer,text,text,text,uuid,boolean) from public,anon,authenticated,service_role;
grant execute on function public.record_move_in_preparation(uuid,integer,text,integer,text,text,text,uuid,boolean) to authenticated;
