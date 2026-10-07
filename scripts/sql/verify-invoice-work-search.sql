begin;
insert into auth.users(id,email,email_confirmed_at) values
('44556600-0000-4000-8000-000000000001','owner-admin@example.invalid',now()),
('44556600-0000-4000-8000-000000000002','approved-owner@example.invalid',now()),
('44556600-0000-4000-8000-000000000003','owner-manager@example.invalid',now()),
('44556600-0000-4000-8000-000000000004','other-owner@example.invalid',now()),
('44556600-0000-4000-8000-000000000005','unverified-owner@example.invalid',null),
('44556600-0000-4000-8000-000000000006','foreign-owner-admin@example.invalid',now());
insert into public.organizations(id,name) values('44556600-0000-4000-8000-000000000010','Owner fixture'),('44556600-0000-4000-8000-000000000011','Foreign owner fixture');
insert into public.staff_accounts(user_id,organization_id,role) values
('44556600-0000-4000-8000-000000000001','44556600-0000-4000-8000-000000000010','admin'),
('44556600-0000-4000-8000-000000000003','44556600-0000-4000-8000-000000000010','manager'),
('44556600-0000-4000-8000-000000000006','44556600-0000-4000-8000-000000000011','admin');
insert into public.properties(id,organization_id,name) values
('44556600-0000-4000-8000-000000000020','44556600-0000-4000-8000-000000000010','Approved owner property'),
('44556600-0000-4000-8000-000000000021','44556600-0000-4000-8000-000000000011','Foreign owner property');
insert into public.staff_accounts(user_id,organization_id,role) values('44556600-0000-4000-8000-000000000002','44556600-0000-4000-8000-000000000010','finance');
insert into public.work_orders(property_id,organization_id,title,description) select '44556600-0000-4000-8000-000000000020','44556600-0000-4000-8000-000000000010','Job '||lpad(n::text,2,'0'),'Private report contents' from generate_series(1,27)n;
insert into public.work_orders(property_id,organization_id,title) values('44556600-0000-4000-8000-000000000020','44556600-0000-4000-8000-000000000010','Literal %_ job'),('44556600-0000-4000-8000-000000000021','44556600-0000-4000-8000-000000000011','Foreign job');
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ declare r jsonb;begin
 r:=public.search_invoice_work_orders('44556600-0000-4000-8000-000000000020','Job');
 if jsonb_array_length(r->'items')<>25 or r->>'more'<>'true' then raise exception 'Bounded work search failed';end if;
 if exists(select 1 from jsonb_array_elements(r->'items')x where (select count(*) from jsonb_object_keys(x))<>2 or not(x?'id' and x?'label')) then raise exception 'Search disclosure failed';end if;
 r:=public.search_invoice_work_orders('44556600-0000-4000-8000-000000000020','%_');if jsonb_array_length(r->'items')<>1 or r#>>'{items,0,label}'<>'Literal %_ job' then raise exception 'Literal search failed';end if;
 begin perform public.search_invoice_work_orders('44556600-0000-4000-8000-000000000021','');raise exception 'Foreign property allowed';exception when insufficient_privilege then null;end;
 begin perform public.search_invoice_work_orders(null,'');raise exception 'Missing parent allowed';exception when invalid_parameter_value then null;end;
 begin perform public.search_invoice_work_orders('44556600-0000-4000-8000-000000000020',repeat('x',121));raise exception 'Unbounded search allowed';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);
do $$ begin begin perform public.search_invoice_work_orders('44556600-0000-4000-8000-000000000020','');raise exception 'Manager finance search allowed';exception when insufficient_privilege then null;end;end $$;
rollback;
