-- SHADE Lot 1A.5 — private label storage for product lots
-- Local/versioned migration. No remote project linkage.

-- Storage buckets are data rows, so they are created explicitly in a hand-written migration.
insert into storage.buckets (id, name, public)
values ('lot-labels', 'lot-labels', false)
on conflict (id) do update
set name = excluded.name,
    public = false;

alter table public.product_lots
  add column label_object_path text;

alter table public.product_lots
  add constraint product_lots_label_object_path_check
  check (
    label_object_path is null
    or label_object_path like tenant_id::text || '/' || id::text || '/%'
  );

grant update (label_object_path) on public.product_lots to authenticated;

-- Object path convention:
--   <tenant_id>/<product_lot_id>/<filename>
-- The policy validates both folders against tenant membership and the lot itself.
create policy lot_labels_select_tenant_member
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'lot-labels'
    and exists (
      select 1
      from public.product_lots lot
      join public.tenant_memberships membership
        on membership.tenant_id = lot.tenant_id
      where membership.user_id = (select auth.uid())
        and lot.tenant_id::text = (storage.foldername(name))[1]
        and lot.id::text = (storage.foldername(name))[2]
    )
  );

create policy lot_labels_insert_tenant_member
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'lot-labels'
    and exists (
      select 1
      from public.product_lots lot
      join public.tenant_memberships membership
        on membership.tenant_id = lot.tenant_id
      where membership.user_id = (select auth.uid())
        and lot.tenant_id::text = (storage.foldername(name))[1]
        and lot.id::text = (storage.foldername(name))[2]
    )
  );
