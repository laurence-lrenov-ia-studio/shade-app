-- pgTAP test intended for `supabase test db` once a local Supabase runtime is available.
begin;

create extension if not exists pgtap;
select plan(15);

-- Stable fixture ids.
insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-0000000000a1', 'tenant-a@example.test'),
  ('00000000-0000-0000-0000-0000000000b1', 'tenant-b@example.test');

insert into public.tenants (id, name, created_by)
values
  ('10000000-0000-0000-0000-0000000000a1', 'Tenant A', '00000000-0000-0000-0000-0000000000a1'),
  ('10000000-0000-0000-0000-0000000000b1', 'Tenant B', '00000000-0000-0000-0000-0000000000b1');


insert into public.products (id, tenant_id, name, product_type, brand, reference, unit, created_by)
values
  ('20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-0000000000a1', 'Product A', 'generic', 'Brand A', 'REF-A', 'unit', '00000000-0000-0000-0000-0000000000a1'),
  ('20000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-0000000000b1', 'Product B', 'generic', 'Brand B', 'REF-B', 'unit', '00000000-0000-0000-0000-0000000000b1');

insert into public.product_lots (id, tenant_id, product_id, lot_number, initial_quantity, received_on, created_by)
values
  ('30000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-0000000000a1', '20000000-0000-0000-0000-0000000000a1', 'LOT-A', 10, current_date, '00000000-0000-0000-0000-0000000000a1'),
  ('30000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-0000000000b1', '20000000-0000-0000-0000-0000000000b1', 'LOT-B', 20, current_date, '00000000-0000-0000-0000-0000000000b1');

set local role anon;

select throws_ok(
  $$ select * from public.tenants $$,
  '42501',
  null,
  'Anon cannot read tenants'
);

select throws_ok(
  $$ select * from public.products $$,
  '42501',
  null,
  'Anon cannot read products'
);

select throws_ok(
  $$ select * from public.product_lot_stock $$,
  '42501',
  null,
  'Anon cannot read current stock'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select results_eq(
  $$ select count(*)::bigint from public.tenants $$,
  array[1::bigint],
  'Tenant A user sees only its tenant'
);

select results_eq(
  $$ select count(*)::bigint from public.tenant_memberships $$,
  array[1::bigint],
  'Tenant A user sees only its own membership'
);

select results_eq(
  $$ select count(*)::bigint from public.products $$,
  array[1::bigint],
  'Tenant A user sees only Tenant A products'
);

select results_eq(
  $$ select count(*)::bigint from public.product_lots $$,
  array[1::bigint],
  'Tenant A user sees only Tenant A lots'
);

select results_eq(
  $$ select count(*)::bigint from public.stock_movements $$,
  array[1::bigint],
  'Tenant A user sees only Tenant A initial movements'
);

select results_eq(
  $$ select count(*)::bigint from public.product_lot_stock $$,
  array[1::bigint],
  'Security-invoker stock view preserves tenant isolation'
);

select throws_ok(
  $$ insert into public.products (tenant_id, name, unit) values ('10000000-0000-0000-0000-0000000000b1', 'Forbidden', 'unit') $$,
  '42501',
  null,
  'Tenant A cannot insert a product into Tenant B'
);

select throws_ok(
  $$ insert into public.product_lots (tenant_id, product_id, lot_number, initial_quantity, received_on) values ('10000000-0000-0000-0000-0000000000b1', '20000000-0000-0000-0000-0000000000b1', 'FORBIDDEN', 1, current_date) $$,
  '42501',
  null,
  'Tenant A cannot insert a lot into Tenant B'
);

select throws_ok(
  $$ insert into public.stock_movements (tenant_id, product_lot_id, movement_type, quantity_delta) values ('10000000-0000-0000-0000-0000000000b1', '30000000-0000-0000-0000-0000000000b1', 'receipt', 1) $$,
  '42501',
  null,
  'Tenant A cannot add a movement to Tenant B'
);

select throws_ok(
  $$ insert into public.stock_movements (tenant_id, product_lot_id, movement_type, quantity_delta) values ('10000000-0000-0000-0000-0000000000a1', '30000000-0000-0000-0000-0000000000a1', 'initial', 1) $$,
  '42501',
  null,
  'Authenticated users cannot forge an additional initial movement'
);

select throws_ok(
  $$ insert into public.tenant_memberships (tenant_id, user_id) values ('10000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1') $$,
  '42501',
  null,
  'Tenant A user cannot self-join Tenant B'
);

select lives_ok(
  $$ insert into public.products (tenant_id, name, unit) values ('10000000-0000-0000-0000-0000000000a1', 'Allowed', 'unit') $$,
  'Tenant A can insert a product into Tenant A'
);

select * from finish();
rollback;
