-- Contractor reports are immutable evidence snapshots; managers review separately.
alter table public.contractor_work_offers drop constraint contractor_work_offers_state_check;
alter table public.contractor_work_offers add constraint contractor_work_offers_state_check check(state in('offered','accepted','declined','withdrawn','expired','completed'));
alter table public.contractor_visits drop constraint contractor_visits_state_check;
alter table public.contractor_visits add constraint contractor_visits_state_check check(state in('proposed','confirmed','declined','cancelled','completed'));
alter table public.work_order_changes drop constraint work_order_changes_action_check;
alter table public.work_order_changes add constraint work_order_changes_action_check check(action in('create','triage','cancel','assign','unassign','schedule','unschedule','check_in','check_out','submit_completion','request_changes','approve_completion'));
create table public.contractor_completion_reports(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),offer_id uuid not null references public.contractor_work_offers(id),work_order_id uuid not null references public.work_orders(id),contractor_user_id uuid not null references auth.users(id),
 summary text not null check(length(trim(summary)) between 20 and 4000),tests_performed text not null check(length(trim(tests_performed)) between 10 and 2000),outstanding_items text not null check(length(trim(outstanding_items)) between 5 and 2000),
 state text not null default 'submitted' check(state in('submitted','changes_requested','approved')),version integer not null default 1 check(version>0),review_message text,reviewed_by uuid references auth.users(id),reviewed_at timestamptz,created_at timestamptz not null default now(),
 check((state='submitted')=(reviewed_by is null and reviewed_at is null)),check(reviewed_by is null or reviewed_by<>contractor_user_id)
);
create unique index completion_report_pending_idx on public.contractor_completion_reports(offer_id) where state='submitted';
create index completion_report_org_history_idx on public.contractor_completion_reports(organization_id,work_order_id,created_at desc,id);
create index completion_report_contractor_idx on public.contractor_completion_reports(contractor_user_id,offer_id,created_at desc,id);
alter table public.contractor_completion_reports enable row level security;
revoke all on public.contractor_completion_reports from public,anon,authenticated;
grant select on public.contractor_completion_reports to authenticated;
grant select,insert,update on public.contractor_completion_reports to service_role;
create policy "management read completion reports" on public.contractor_completion_reports for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create policy "contractor read own completion reports" on public.contractor_completion_reports for select to authenticated using(contractor_user_id=(select private.verified_contractor_user()));
create table public.contractor_completion_changes(
 id uuid primary key default gen_random_uuid(),report_id uuid not null references public.contractor_completion_reports(id),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,action text not null,previous_state text,new_state text not null,version integer not null,reason text not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index completion_changes_history_idx on public.contractor_completion_changes(organization_id,report_id,created_at desc,id);
alter table public.contractor_completion_changes enable row level security;
revoke all on public.contractor_completion_changes from public,anon,authenticated;
grant select on public.contractor_completion_changes to authenticated;
grant select,insert on public.contractor_completion_changes to service_role;
create policy "management read completion audit" on public.contractor_completion_changes for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create function private.guard_completion_report_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and row(new.organization_id,new.offer_id,new.work_order_id,new.contractor_user_id,new.summary,new.tests_performed,new.outstanding_items,new.created_at) is distinct from row(old.organization_id,old.offer_id,old.work_order_id,old.contractor_user_id,old.summary,old.tests_performed,old.outstanding_items,old.created_at) then raise exception 'Submitted evidence and identity immutable' using errcode='23505';end if;
 if not exists(select 1 from public.contractor_work_offers o join public.contractor_accounts c on c.id=o.contractor_id where o.id=new.offer_id and o.work_order_id=new.work_order_id and o.organization_id=new.organization_id and c.user_id=new.contractor_user_id) then raise exception 'Completion report assignment binding required' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_completion_report_binding() from public,anon,authenticated;
create trigger guard_completion_report_binding before insert or update on public.contractor_completion_reports for each row execute function private.guard_completion_report_binding();
create function private.manage_completion_report(p_request_id uuid,p_action text,p_offer_id uuid,p_report_id uuid,p_expected_offer_version integer,p_expected_report_version integer,p_summary text,p_tests_performed text,p_outstanding_items text,p_review_message text,p_reason text,p_evidence_reviewed boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();offer public.contractor_work_offers;job public.work_orders;report public.contractor_completion_reports;event public.contractor_completion_changes;payload jsonb;org uuid;created uuid;next_state text;next_version integer;work_action text;
begin
 if caller is null or private.verified_contractor_user() is null then raise exception 'Verified account required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('submit','request_changes','approve') or p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'Valid completion action and reason required' using errcode='22023';end if;
 if p_action='submit' then select * into offer from public.contractor_work_offers where id=p_offer_id;
 else select * into report from public.contractor_completion_reports where id=p_report_id;select * into offer from public.contractor_work_offers where id=report.offer_id;end if;
 if offer.id is null then raise exception 'Authorized assignment required' using errcode='42501';end if;org:=offer.organization_id;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if p_action='submit' then
 if not exists(select 1 from public.contractor_accounts c join auth.users u on u.id=c.user_id where c.id=offer.contractor_id and c.user_id=caller and c.is_active and u.email_confirmed_at is not null) then raise exception 'Current assigned contractor required' using errcode='42501';end if;
 else
 if private.verified_work_order_organization() is distinct from org or caller=report.contractor_user_id then raise exception 'Independent organization manager required' using errcode='42501';end if;
 end if;
 payload:=jsonb_build_object('action',p_action,'offer_id',p_offer_id,'report_id',p_report_id,'offer_version',p_expected_offer_version,'report_version',p_expected_report_version,'summary',trim(p_summary),'tests',trim(p_tests_performed),'outstanding',trim(p_outstanding_items),'review_message',trim(p_review_message),'reason',trim(p_reason),'evidence_reviewed',p_evidence_reviewed);
 select * into event from public.contractor_completion_changes where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then if event.organization_id<>org or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;return jsonb_build_object('id',event.report_id,'state',event.new_state,'version',event.version);end if;
 select * into job from public.work_orders where id=offer.work_order_id for update;
 select * into offer from public.contractor_work_offers where id=offer.id for update;
 if offer.state<>'accepted' or job.status<>'in_progress' or offer.work_version<>job.revision or exists(select 1 from public.contractor_presence where visit_id in(select id from public.contractor_visits where offer_id=offer.id) and state='on_site') or exists(select 1 from public.contractor_visits where offer_id=offer.id and state='proposed') or exists(select 1 from public.contractor_visits v where v.offer_id=offer.id and v.state='confirmed' and not exists(select 1 from public.contractor_presence p where p.visit_id=v.id and p.state='exited')) or not exists(select 1 from public.contractor_presence p join public.contractor_visits v on v.id=p.visit_id where v.offer_id=offer.id and p.state='exited') then raise exception 'Current in-progress work and recorded departure required' using errcode='23505';end if;
 if p_action='submit' then
 if p_report_id is not null or p_expected_report_version is distinct from 0 or p_expected_offer_version is null or p_expected_offer_version<1 or p_review_message is not null or p_evidence_reviewed is not null or p_summary is null or length(trim(p_summary)) not between 20 and 4000 or p_tests_performed is null or length(trim(p_tests_performed)) not between 10 and 2000 or p_outstanding_items is null or length(trim(p_outstanding_items)) not between 5 and 2000 then raise exception 'Completion evidence and current assignment revision required' using errcode='22023';end if;
 if offer.version<>p_expected_offer_version then raise exception 'Assignment changed' using errcode='40001';end if;
 insert into public.contractor_completion_reports(organization_id,offer_id,work_order_id,contractor_user_id,summary,tests_performed,outstanding_items) values(org,offer.id,job.id,caller,trim(p_summary),trim(p_tests_performed),trim(p_outstanding_items)) returning id into created;next_state:='submitted';next_version:=1;work_action:='submit_completion';
 else
 if p_offer_id is not null or p_expected_offer_version is not null or p_expected_report_version is null or p_expected_report_version<1 or p_expected_report_version>=2147483647 or p_summary is not null or p_tests_performed is not null or p_outstanding_items is not null or p_review_message is null or length(trim(p_review_message)) not between 10 and 2000 or (p_action='approve' and p_evidence_reviewed is distinct from true) or (p_action='request_changes' and p_evidence_reviewed is not null) then raise exception 'Current report revision and shared review required' using errcode='22023';end if;
 select * into report from public.contractor_completion_reports where id=p_report_id for update;
 if report.version<>p_expected_report_version then raise exception 'Report changed' using errcode='40001';end if;
 if report.state<>'submitted' then raise exception 'Submitted report required' using errcode='23505';end if;
 created:=report.id;next_state:=case when p_action='approve' then 'approved' else 'changes_requested' end;next_version:=report.version+1;work_action:=case when p_action='approve' then 'approve_completion' else 'request_changes' end;
 update public.contractor_completion_reports set state=next_state,version=next_version,review_message=trim(p_review_message),reviewed_by=caller,reviewed_at=now() where id=report.id;
 end if;
 if p_action='approve' then
 update public.contractor_visits set state='completed',version=version+1 where offer_id=offer.id and state='confirmed';
 update public.contractor_work_offers set state='completed',version=version+1,work_version=job.revision+1 where id=offer.id;
 else update public.contractor_work_offers set version=version+1,work_version=job.revision+1 where id=offer.id;end if;
 update public.work_orders set status=case when p_action='approve' then 'completed' else status end,completed_at=case when p_action='approve' then now() else completed_at end,revision=revision+1 where id=job.id;
 insert into public.work_order_changes(work_order_id,organization_id,actor_user_id,request_id,payload,action,previous_status,new_status,previous_priority,new_priority,version,reason) values(job.id,org,caller,p_request_id,jsonb_build_object('report_id',created),work_action,job.status,case when p_action='approve' then 'completed' else job.status end,job.priority,job.priority,job.revision+1,trim(p_reason));
 insert into public.contractor_completion_changes(report_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(created,org,caller,p_request_id,payload,p_action,report.state,next_state,next_version,trim(p_reason));
 return jsonb_build_object('id',created,'state',next_state,'version',next_version);
end $$;
revoke all on function private.manage_completion_report(uuid,text,uuid,uuid,integer,integer,text,text,text,text,text,boolean) from public,anon,authenticated;
grant execute on function private.manage_completion_report(uuid,text,uuid,uuid,integer,integer,text,text,text,text,text,boolean) to authenticated;
create function public.manage_completion_report(p_request_id uuid,p_action text,p_offer_id uuid,p_report_id uuid,p_expected_offer_version integer,p_expected_report_version integer,p_summary text,p_tests_performed text,p_outstanding_items text,p_review_message text,p_reason text,p_evidence_reviewed boolean) returns jsonb language sql security invoker set search_path='' as $$select private.manage_completion_report(p_request_id,p_action,p_offer_id,p_report_id,p_expected_offer_version,p_expected_report_version,p_summary,p_tests_performed,p_outstanding_items,p_review_message,p_reason,p_evidence_reviewed);$$;
revoke all on function public.manage_completion_report(uuid,text,uuid,uuid,integer,integer,text,text,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.manage_completion_report(uuid,text,uuid,uuid,integer,integer,text,text,text,text,text,boolean) to authenticated;
