alter table public.contractor_evidence_events alter column actor_user_id drop not null;
create function public.claim_expired_contractor_evidence() returns table(id uuid,object_path text) language plpgsql security invoker set search_path='' as $$
declare doc public.contractor_evidence;
begin
 for doc in select e.* from public.contractor_evidence e where e.purged_at is null and e.expires_at+interval '2 hours 5 minutes'<now() and e.state in('reserved','expired','withdrawn') and not exists(select 1 from public.contractor_report_evidence r where r.evidence_id=e.id) order by e.created_at,e.id limit 20 for update skip locked loop
 if doc.state='reserved' then
 update public.contractor_evidence e set state='expired' where e.id=doc.id;
 insert into public.contractor_evidence_events(evidence_id,actor_user_id,event_name) values(doc.id,null,'reservation_expired');
 end if;
 id:=doc.id;object_path:=doc.object_path;return next;
 end loop;
end $$;
revoke all on function public.claim_expired_contractor_evidence() from public,anon,authenticated;
grant execute on function public.claim_expired_contractor_evidence() to service_role;
