-- pgTAP: private lot-label Storage isolation.
begin;

create extension if not exists pgtap;
select plan(8);

select is(
  (select public from storage.buckets where id = 'lot-labels'),
  false,
  'Lot-labels bucket is private'
);

insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-0000000000d1', 'storage-a@example.test'),
  ('00000000-0000-0000-0000-0000000000e1', 'storage-b@example.test');

insert into public.tenants (id, name, created_by)
values
  ('10000000-0000-0000-0000-0000000000d1', 'Storage Tenant A', '00000000-0000-0000-0000-0000000000d1'),
  ('10000000-0000-0000-0000-0000000000e1', 'Storage Tenant B', '00000000-0000-0000-0000-0000000000e1');

insert into public.products (id, tenant_id, name, unit, created_by)
values
  ('20000000-0000-0000-0000-0000000000d1', '10000000-0000-0000-0000-0000000000d1', 'Storage Product A', 'unit', '00000000-0000-0000-0000-0000000000d1'),
  ('20000000-0000-0000-0000-0000000000e1', '10000000-0000-0000-0000-0000000000e1', 'Storage Product B', 'unit', '00000000-0000-0000-0000-0000000000e1');

insert into public.product_lots (id, tenant_id, product_id, lot_number, initial_quantity, received_on, created_by)
values
  ('30000000-0000-0000-0000-0000000000d1', '10000000-0000-0000-0000-0000000000d1', '20000000-0000-0000-0000-0000000000d1', 'LOT-STORAGE-A', 1, current_date, '00000000-0000-0000-0000-0000000000d1'),
  ('30000000-0000-0000-0000-0000000000e1', '10000000-0000-0000-0000-0000000000e1', '20000000-0000-0000-0000-0000000000e1', 'LOT-STORAGE-B', 1, current_date, '00000000-0000-0000-0000-0000000000e1');

-- Fixture object metadata is inserted as the test owner, before switching to authenticated.
-- The transaction is rolled back at the end; production object operations remain API-only.
insert into storage.objects (bucket_id, name, owner_id)
values
  ('lot-labels', '10000000-0000-0000-0000-0000000000d1/30000000-0000-0000-0000-0000000000d1/label-a.jpg', '00000000-0000-0000-0000-0000000000d1'),
  ('lot-labels', '10000000-0000-0000-0000-0000000000e1/30000000-0000-0000-0000-0000000000e1/label-b.jpg', '00000000-0000-0000-0000-0000000000e1');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000d1', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select results_eq(
  $$ select count(*)::bigint from storage.objects where bucket_id = 'lot-labels' $$,
  array[1::bigint],
  'Tenant A sees only its own lot label object'
);

select lives_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id) values ('lot-labels', '10000000-0000-0000-0000-0000000000d1/30000000-0000-0000-0000-0000000000d1/label-a-2.jpg', '00000000-0000-0000-0000-0000000000d1') $$,
  'Tenant A can add an object under its own tenant and lot path'
);

select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id) values ('lot-labels', '10000000-0000-0000-0000-0000000000e1/30000000-0000-0000-0000-0000000000e1/forbidden.jpg', '00000000-0000-0000-0000-0000000000d1') $$,
  '42501',
  null,
  'Tenant A cannot add an object under Tenant B path'
);

select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id) values ('lot-labels', '10000000-0000-0000-0000-0000000000d1/30000000-0000-0000-0000-0000000000e1/cross-lot.jpg', '00000000-0000-0000-0000-0000000000d1') $$,
  '42501',
  null,
  'Tenant path and lot path must belong to the same tenant'
);

select lives_ok(
  $$ update public.product_lots set label_object_path = '10000000-0000-0000-0000-0000000000d1/30000000-0000-0000-0000-0000000000d1/label-a.jpg' where id = '30000000-0000-0000-0000-0000000000d1' $$,
  'Tenant A can reference its own structured label path'
);

select throws_ok(
  $$ update public.product_lots set label_object_path = '10000000-0000-0000-0000-0000000000e1/30000000-0000-0000-0000-0000000000e1/label-b.jpg' where id = '30000000-0000-0000-0000-0000000000d1' $$,
  '23514',
  null,
  'A lot cannot reference a label path outside its own tenant and lot prefix'
);

select throws_ok(
  $$ delete from storage.objects where bucket_id = 'lot-labels' and name like '10000000-0000-0000-0000-0000000000d1/%' $$,
  '42501',
  null,
  'Authenticated clients cannot delete label objects in this pass'
);

select * from finish();
rollback;
