create function private.staff_invitation_summary(p_invitation_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare inv public.staff_invitations; email text:=private.verified_staff_invitation_email(); org_name text; blocked text; recipient boolean;
begin
 if email is null then raise exception 'Verified account required' using errcode='42501';end if;
 select * into inv from public.staff_invitations where id=p_invitation_id;
 if inv.id is null then return null;end if;
 recipient:=inv.invite_email=email;
 if not recipient and private.verified_staff_admin_organization() is distinct from inv.organization_id then return null;end if;
 select name into org_name from public.organizations where id=inv.organization_id;
 blocked:=case when not recipient then 'Sign in with the invited email to respond.'
 when inv.state<>'pending' then 'This invitation is already closed.'
 when inv.expires_at<=statement_timestamp() then 'This invitation has expired. Request a new invitation.'
 when exists(select 1 from public.staff_accounts where user_id=auth.uid()) then 'You already have staff access. Ask an administrator to manage your existing membership.'
 when not exists(select 1 from public.staff_accounts a join auth.users u on u.id=a.user_id where a.user_id=inv.created_by and a.organization_id=inv.organization_id and a.role='admin' and u.email_confirmed_at is not null) then 'Administrator approval has changed. Request a new invitation.' else null end;
 return jsonb_build_object('id',inv.id,'organization_name',org_name,'invite_email',inv.invite_email,'role',inv.role,'state',inv.state,'version',inv.version,'expires_at',inv.expires_at,'can_accept',blocked is null,'can_decline',recipient and inv.state='pending' and inv.expires_at>statement_timestamp(),'blocked_reason',blocked);
end;$$;
revoke all on function private.staff_invitation_summary(uuid) from public,anon,authenticated,service_role;
grant execute on function private.staff_invitation_summary(uuid) to authenticated;
create function public.staff_invitation_summary(p_invitation_id uuid) returns jsonb language sql security invoker set search_path='' as $$select private.staff_invitation_summary(p_invitation_id);$$;
revoke all on function public.staff_invitation_summary(uuid) from public,anon,authenticated,service_role;
grant execute on function public.staff_invitation_summary(uuid) to authenticated;
