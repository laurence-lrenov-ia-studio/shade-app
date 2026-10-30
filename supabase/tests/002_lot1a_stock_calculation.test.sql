-- pgTAP stock journal and calculation test intended for `supabase test db`.
begin;

create extension if not exists pgtap;
select plan(9);

insert into auth.users (id, email)
values ('00000000-0000-0000-0000-0000000000c1', 'stock@example.test');

insert into public.tenants (id, name, created_by)
values ('10000000-0000-0000-0000-0000000000c1', 'Stock Tenant', '00000000-0000-0000-0000-0000000000c1');


insert into public.products (id, tenant_id, name, unit, created_by)
values ('20000000-0000-0000-0000-0000000000c1', '10000000-0000-0000-0000-0000000000c1', 'Generic Product', 'ml', '00000000-0000-0000-0000-0000000000c1');

insert into public.product_lots (id, tenant_id, product_id, lot_number, initial_quantity, received_on, created_by)
values ('30000000-0000-0000-0000-0000000000c1', '10000000-0000-0000-0000-0000000000c1', '20000000-0000-0000-0000-0000000000c1', 'LOT-C', 10, current_date, '00000000-0000-0000-0000-0000000000c1');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select results_eq(
  $$ select count(*)::bigint from public.stock_movements where product_lot_id = '30000000-0000-0000-0000-0000000000c1' $$,
  array[1::bigint],
  'Creating a lot creates exactly one initial movement'
);

select results_eq(
  $$ select current_quantity from public.product_lot_stock where product_lot_id = '30000000-0000-0000-0000-0000000000c1' $$,
  array[10.0000::numeric],
  'Initial stock equals initial quantity'
);

insert into public.stock_movements (tenant_id, product_lot_id, movement_type, quantity_delta)
values ('10000000-0000-0000-0000-0000000000c1', '30000000-0000-0000-0000-0000000000c1', 'receipt', 5);

insert into public.stock_movements (tenant_id, product_lot_id, movement_type, quantity_delta)
values ('10000000-0000-0000-0000-0000000000c1', '30000000-0000-0000-0000-0000000000c1', 'issue', -3);

insert into public.stock_movements (tenant_id, product_lot_id, movement_type, quantity_delta, reason)
values ('10000000-0000-0000-0000-0000000000c1', '30000000-0000-0000-0000-0000000000c1', 'loss', -1, 'Damaged stock');

insert into public.stock_movements (tenant_id, product_lot_id, movement_type, quantity_delta, reason)
values ('10000000-0000-0000-0000-0000000000c1', '30000000-0000-0000-0000-0000000000c1', 'adjustment', 0.5, 'Inventory correction');

select results_eq(
  $$ select current_quantity from public.product_lot_stock where product_lot_id = '30000000-0000-0000-0000-0000000000c1' $$,
  array[11.5000::numeric],
  'Current stock is the sum of immutable movements'
);

select throws_ok(
  $$ insert into public.stock_movements (tenant_id, product_lot_id, movement_type, quantity_delta) values ('10000000-0000-0000-0000-0000000000c1', '30000000-0000-0000-0000-0000000000c1', 'issue', -12) $$,
  '23514',
  'Stock movement would make current stock negative',
  'A movement cannot make stock negative'
);

select throws_ok(
  $$ insert into public.stock_movements (tenant_id, product_lot_id, movement_type, quantity_delta) values ('10000000-0000-0000-0000-0000000000c1', '30000000-0000-0000-0000-0000000000c1', 'loss', -1) $$,
  '23514',
  null,
  'Loss requires a reason'
);

select throws_ok(
  $$ update public.stock_movements set reason = 'Changed' where product_lot_id = '30000000-0000-0000-0000-0000000000c1' $$,
  '42501',
  null,
  'Authenticated role has no UPDATE grant on movement history'
);

select throws_ok(
  $$ delete from public.stock_movements where product_lot_id = '30000000-0000-0000-0000-0000000000c1' $$,
  '42501',
  null,
  'Authenticated role has no DELETE grant on movement history'
);

select throws_ok(
  $$ update public.product_lots set initial_quantity = 99 where id = '30000000-0000-0000-0000-0000000000c1' $$,
  '42501',
  null,
  'Initial quantity is not editable after lot creation'
);

select results_eq(
  $$ select count(*)::bigint from public.stock_movements where product_lot_id = '30000000-0000-0000-0000-0000000000c1' $$,
  array[5::bigint],
  'Rejected operations do not alter movement history'
);

select * from finish();
rollback;
