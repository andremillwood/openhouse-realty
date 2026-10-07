-- Zero is a draft placeholder, not an approved advertised price.
alter table public.listings add constraint listings_public_price_ready check(status<>'published' or price_jmd>0);
