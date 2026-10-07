create table public.application_document_reviews (
 document_id uuid primary key references public.application_documents(id),
 application_id uuid not null references public.rental_applications(id),
 organization_id uuid not null references public.organizations(id),
 status text not null check(status in('verified','needs_info','not_accepted')),
 reason text not null check(length(reason) between 5 and 2000),
 file_sha256 text not null check(file_sha256 ~ '^[a-f0-9]{64}$'),
 reviewer_user_id uuid not null references auth.users(id),
 version integer not null check(version>0),
 updated_at timestamptz not null default now()
);
create index application_document_reviews_app_idx on public.application_document_reviews(application_id);
create index application_document_reviews_org_idx on public.application_document_reviews(organization_id);
create table public.application_document_review_events (
 id uuid primary key default gen_random_uuid(),
 document_id uuid not null references public.application_documents(id),
 application_id uuid not null references public.rental_applications(id),
 organization_id uuid not null references public.organizations(id),
 actor_user_id uuid not null references auth.users(id),
 request_id uuid not null,
 old_status text,
 new_status text not null check(new_status in('verified','needs_info','not_accepted')),
 reason text not null check(length(reason) between 5 and 2000),
 file_sha256 text not null,
 version integer not null,
 created_at timestamptz not null default now(),
 unique(document_id,actor_user_id,request_id)
);
create index application_document_review_events_app_idx on public.application_document_review_events(application_id,created_at desc);
create index application_document_review_events_actor_idx on public.application_document_review_events(actor_user_id,created_at desc);
create index application_document_review_events_org_idx on public.application_document_review_events(organization_id);
alter table public.application_document_reviews enable row level security;
alter table public.application_document_review_events enable row level security;
revoke all on public.application_document_reviews,public.application_document_review_events from public,anon,authenticated;
grant select on public.application_document_reviews,public.application_document_review_events to authenticated;
grant select,insert,update on public.application_document_reviews to service_role;
grant select,insert on public.application_document_review_events to service_role;
create policy "independent verified staff read document review" on public.application_document_reviews for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()) and exists(select 1 from public.rental_applications a where a.id=application_id and a.user_id<>(select auth.uid())));
create policy "independent verified staff read document review audit" on public.application_document_review_events for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()) and exists(select 1 from public.rental_applications a where a.id=application_id and a.user_id<>(select auth.uid())));

create function private.review_application_document(p_document_id uuid,p_request_id uuid,p_expected_version integer,p_status text,p_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); doc public.application_documents; application public.rental_applications; review public.application_document_reviews; event public.application_document_review_events; next_version integer;
begin
 if caller is null or private.verified_enquiry_staff_organization() is null then raise exception 'Verified staff required' using errcode='42501';end if;
 if p_request_id is null or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_status is null or p_status not in('verified','needs_info','not_accepted') or p_reason is null or length(trim(p_reason)) not between 5 and 2000 then raise exception 'Valid document decision and reason required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,113));
 select * into doc from public.application_documents where id=p_document_id;
 select * into application from public.rental_applications where id=doc.application_id for update;
 if application.id is null or application.user_id=caller or application.organization_id is distinct from private.verified_enquiry_staff_organization() then raise exception 'Independent organization reviewer required' using errcode='42501';end if;
 select * into doc from public.application_documents where id=p_document_id for update;
 select * into review from public.application_document_reviews where document_id=doc.id;
 select * into event from public.application_document_review_events where document_id=doc.id and actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then
  if event.new_status<>p_status or event.reason<>trim(p_reason) or event.version<>p_expected_version+1 then raise exception 'Request ID already used' using errcode='22023';end if;
  return jsonb_build_object('status',review.status,'version',review.version);
 end if;
 if application.status<>'under_review' or doc.state<>'uploaded' or doc.sha256 is null then raise exception 'Review requires an uploaded file and application under review' using errcode='22023';end if;
 if coalesce(review.version,0)<>p_expected_version then raise exception 'Document review changed; refresh before recording a decision' using errcode='40001';end if;
 if (select count(*) from public.application_document_review_events where actor_user_id=caller and created_at>now()-interval '1 day')>=200 then raise exception 'Daily review limit reached' using errcode='P0001';end if;
 next_version:=p_expected_version+1;
 insert into public.application_document_reviews(document_id,application_id,organization_id,status,reason,file_sha256,reviewer_user_id,version) values(doc.id,application.id,application.organization_id,p_status,trim(p_reason),doc.sha256,caller,next_version)
 on conflict(document_id) do update set status=excluded.status,reason=excluded.reason,file_sha256=excluded.file_sha256,reviewer_user_id=excluded.reviewer_user_id,version=excluded.version,updated_at=now();
 insert into public.application_document_review_events(document_id,application_id,organization_id,actor_user_id,request_id,old_status,new_status,reason,file_sha256,version) values(doc.id,application.id,application.organization_id,caller,p_request_id,review.status,p_status,trim(p_reason),doc.sha256,next_version);
 return jsonb_build_object('status',p_status,'version',next_version);
end $$;
revoke all on function private.review_application_document(uuid,uuid,integer,text,text) from public,anon;
grant execute on function private.review_application_document(uuid,uuid,integer,text,text) to authenticated;
create function public.review_application_document(p_document_id uuid,p_request_id uuid,p_expected_version integer,p_status text,p_reason text) returns jsonb language sql security invoker set search_path='' as $$select private.review_application_document(p_document_id,p_request_id,p_expected_version,p_status,p_reason);$$;
revoke all on function public.review_application_document(uuid,uuid,integer,text,text) from public,anon;
grant execute on function public.review_application_document(uuid,uuid,integer,text,text) to authenticated;
