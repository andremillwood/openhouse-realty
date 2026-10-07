begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('99115544-0000-4000-8000-000000000001','saved-owner@example.invalid',now()),
 ('99115544-0000-4000-8000-000000000002','saved-other@example.invalid',now()),
 ('99115544-0000-4000-8000-000000000003','saved-unverified@example.invalid',null);
insert into public.organizations(id,name) values ('99115544-0000-4000-8000-000000000004','Saved property fixture');
insert into public.listings(id,organization_id,title,area,intent,property_type,status,price_jmd,description,photo_url) values
 ('99115544-0000-4000-8000-000000000005','99115544-0000-4000-8000-000000000004','Published saved fixture','Kingston','rent','house','published',100,'A complete synthetic property description.','https://example.invalid/photo.png'),
 ('99115544-0000-4000-8000-000000000006','99115544-0000-4000-8000-000000000004','Private saved fixture','Kingston','rent','house','draft',100,'A private synthetic property description.','https://example.invalid/photo.png');
select set_config('request.jwt.claim.sub','99115544-0000-4000-8000-000000000001',true);
set local role authenticated;
insert into public.saved_listings(user_id,listing_id) values('99115544-0000-4000-8000-000000000001','99115544-0000-4000-8000-000000000005') on conflict do nothing;
insert into public.saved_listings(user_id,listing_id) values('99115544-0000-4000-8000-000000000001','99115544-0000-4000-8000-000000000005') on conflict do nothing;
do $$ begin
 if (select count(*) from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001')<>1 then raise exception 'Duplicate save or own read denied';end if;
 begin insert into public.saved_listings(user_id,listing_id) values('99115544-0000-4000-8000-000000000002','99115544-0000-4000-8000-000000000005');raise exception 'Foreign save accepted';exception when insufficient_privilege then null;end;
 begin insert into public.saved_listings(user_id,listing_id) values('99115544-0000-4000-8000-000000000001','99115544-0000-4000-8000-000000000006');raise exception 'Draft save accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','99115544-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001') then raise exception 'Foreign read accepted';end if;end $$;
delete from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001';
reset role;
do $$ begin if (select count(*) from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001')<>1 then raise exception 'Foreign delete accepted';end if;end $$;
update auth.users set email_confirmed_at=null where id='99115544-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','99115544-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin if exists(select 1 from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001') then raise exception 'Revoked verification read accepted';end if;end $$;
delete from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','99115544-0000-4000-8000-000000000003',true);
do $$ begin begin insert into public.saved_listings(user_id,listing_id) values('99115544-0000-4000-8000-000000000003','99115544-0000-4000-8000-000000000005');raise exception 'Unverified save accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$ begin if (select count(*) from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001')<>1 then raise exception 'Revoked verification delete accepted';end if;end $$;
update auth.users set email_confirmed_at=now() where id='99115544-0000-4000-8000-000000000001';
update public.listings set status='paused' where id='99115544-0000-4000-8000-000000000005';
select set_config('request.jwt.claim.sub','99115544-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 if (select count(*) from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001')<>1 then raise exception 'Retained shortlist missing';end if;
 if exists(select 1 from public.listings where id='99115544-0000-4000-8000-000000000005' and status='published') then raise exception 'Paused property public details leaked';end if;
end $$;
delete from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001' and listing_id='99115544-0000-4000-8000-000000000005';
delete from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001' and listing_id='99115544-0000-4000-8000-000000000005';
do $$ begin if exists(select 1 from public.saved_listings where user_id='99115544-0000-4000-8000-000000000001') then raise exception 'Own repeated remove failed';end if;end $$;
reset role;
rollback;
select 'PASS: verified owner save/read/remove, duplicate desired saves, foreign/unverified/revoked denial and retained paused-property removal; fixtures rolled back.' as verification;
