-- SHADE Lot 1A.2 — generic products catalogue

create table public.products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  name text not null check (char_length(btrim(name)) > 0),
  product_type text,
  brand text,
  reference text,
  unit text not null check (char_length(btrim(unit)) > 0),
  is_active boolean not null default true,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint products_tenant_id_id_unique unique (tenant_id, id)
);

create index products_tenant_active_idx
  on public.products(tenant_id, is_active);

create index products_tenant_name_idx
  on public.products(tenant_id, name);

alter table public.products enable row level security;

revoke all on public.products from anon, authenticated;
grant select on public.products to authenticated;
grant insert (tenant_id, name, product_type, brand, reference, unit, is_active)
  on public.products to authenticated;
grant update (name, product_type, brand, reference, is_active)
  on public.products to authenticated;

create policy products_select_tenant_member
  on public.products
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = products.tenant_id
        and membership.user_id = (select auth.uid())
    )
  );

create policy products_insert_tenant_member
  on public.products
  for insert
  to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = products.tenant_id
        and membership.user_id = (select auth.uid())
    )
  );

create policy products_update_tenant_member
  on public.products
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = products.tenant_id
        and membership.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = products.tenant_id
        and membership.user_id = (select auth.uid())
    )
  );
