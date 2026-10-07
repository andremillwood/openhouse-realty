-- A correction visit is a new appointment, never a rewrite of attendance or evidence.
alter table public.work_order_changes drop constraint work_order_changes_action_check;
alter table public.work_order_changes add constraint work_order_changes_action_check check(action in('create','triage','cancel','assign','unassign','schedule','unschedule','check_in','check_out','submit_completion','request_changes','approve_completion','return_visit'));
create function private.request_contractor_return_visit(p_request_id uuid,p_report_id uuid,p_expected_report_version integer,p_expected_offer_version integer,p_expected_work_version integer,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_work_order_organization();report public.contractor_completion_reports;offer public.contractor_work_offers;job public.work_orders;visit public.contractor_visits;event public.work_order_changes;payload jsonb;
begin
 if caller is null or org is null then raise exception 'Verified organization manager required' using errcode='42501';end if;
 if p_request_id is null or p_report_id is null or p_expected_report_version is null or p_expected_report_version<1 or p_expected_report_version>=2147483647 or p_expected_offer_version is null or p_expected_offer_version<1 or p_expected_offer_version>=2147483647 or p_expected_work_version is null or p_expected_work_version<1 or p_expected_work_version>=2147483647 or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Current revisions, approval and reason required' using errcode='22023';end if;
 select * into report from public.contractor_completion_reports where id=p_report_id and organization_id=org;
 if report.id is null or report.contractor_user_id=caller then raise exception 'Independent organization manager required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_work_order_organization() is distinct from org then raise exception 'Manager authority changed' using errcode='42501';end if;
 payload:=jsonb_build_object('report_id',p_report_id,'report_version',p_expected_report_version,'offer_version',p_expected_offer_version,'work_version',p_expected_work_version,'reason',trim(p_reason),'approved',p_approved);
 select * into event from public.work_order_changes where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then
 if event.organization_id<>org or event.action<>'return_visit' or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
 return jsonb_build_object('id',event.work_order_id,'state',event.new_status,'version',event.version);
 end if;
 select * into job from public.work_orders where id=report.work_order_id and organization_id=org for update;
 select * into offer from public.contractor_work_offers where id=report.offer_id and organization_id=org for update;
 select * into report from public.contractor_completion_reports where id=p_report_id for update;
 if report.version<>p_expected_report_version or offer.version<>p_expected_offer_version or job.revision<>p_expected_work_version then raise exception 'Correction decision changed' using errcode='40001';end if;
 if report.state<>'changes_requested' or offer.state<>'accepted' or job.status<>'in_progress' or job.completed_at is not null or offer.work_version<>job.revision
 or exists(select 1 from public.contractor_completion_reports where offer_id=offer.id and state='submitted')
 or exists(select 1 from public.contractor_visits v where v.offer_id=offer.id and (v.state='proposed' or (v.state='confirmed' and not exists(select 1 from public.contractor_presence p where p.visit_id=v.id and p.state='exited'))))
 or exists(select 1 from public.contractor_presence p join public.contractor_visits v on v.id=p.visit_id where v.offer_id=offer.id and p.state='on_site')
 or not exists(select 1 from public.contractor_presence p join public.contractor_visits v on v.id=p.visit_id where v.offer_id=offer.id and p.state='exited')
 or not exists(select 1 from public.contractor_accounts c join auth.users u on u.id=c.user_id where c.id=offer.contractor_id and c.is_active and u.email_confirmed_at is not null)
 then raise exception 'Departed correction work with active assignment required' using errcode='23505';end if;
 -- Closing departed appointments also revokes any remaining old permit through its trigger.
 for visit in select * from public.contractor_visits where offer_id=offer.id and state='confirmed' for update loop
 update public.contractor_visits set state='completed',version=version+1 where id=visit.id;
 insert into public.contractor_visit_changes(visit_id,organization_id,actor_user_id,request_id,payload,action,previous_state,new_state,version,reason) values(visit.id,org,caller,gen_random_uuid(),jsonb_build_object('return_request_id',p_request_id,'report_id',report.id),'return_visit','confirmed','completed',visit.version+1,trim(p_reason));
 end loop;
 update public.work_orders set status='assigned',scheduled_start=null,scheduled_end=null,revision=revision+1 where id=job.id;
 update public.contractor_work_offers set work_version=job.revision+1,version=version+1 where id=offer.id;
 insert into public.work_order_changes(work_order_id,organization_id,actor_user_id,request_id,payload,action,previous_status,new_status,previous_priority,new_priority,version,reason) values(job.id,org,caller,p_request_id,payload,'return_visit','in_progress','assigned',job.priority,job.priority,job.revision+1,trim(p_reason));
 return jsonb_build_object('id',job.id,'state','assigned','version',job.revision+1);
end $$;
revoke all on function private.request_contractor_return_visit(uuid,uuid,integer,integer,integer,text,boolean) from public,anon,authenticated;
grant execute on function private.request_contractor_return_visit(uuid,uuid,integer,integer,integer,text,boolean) to authenticated;
create function public.request_contractor_return_visit(p_request_id uuid,p_report_id uuid,p_expected_report_version integer,p_expected_offer_version integer,p_expected_work_version integer,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.request_contractor_return_visit(p_request_id,p_report_id,p_expected_report_version,p_expected_offer_version,p_expected_work_version,p_reason,p_approved);$$;
revoke all on function public.request_contractor_return_visit(uuid,uuid,integer,integer,integer,text,boolean) from public,anon,authenticated;
grant execute on function public.request_contractor_return_visit(uuid,uuid,integer,integer,integer,text,boolean) to authenticated;
