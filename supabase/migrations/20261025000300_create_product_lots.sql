-- SHADE Lot 1A.3 — product lots

create table public.product_lots (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  product_id uuid not null,
  lot_number text not null check (char_length(btrim(lot_number)) > 0),
  initial_quantity numeric(14,4) not null check (initial_quantity > 0),
  received_on date not null,
  opened_on date,
  expires_on date,
  location text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint product_lots_tenant_id_id_unique unique (tenant_id, id),
  constraint product_lots_product_fk
    foreign key (tenant_id, product_id)
    references public.products(tenant_id, id)
    on delete restrict,
  constraint product_lots_product_lot_unique unique (tenant_id, product_id, lot_number),
  constraint product_lots_opened_after_receipt_check
    check (opened_on is null or opened_on >= received_on)
);

create index product_lots_tenant_product_idx
  on public.product_lots(tenant_id, product_id);

create index product_lots_tenant_expiry_idx
  on public.product_lots(tenant_id, expires_on)
  where expires_on is not null;

alter table public.product_lots enable row level security;

revoke all on public.product_lots from anon, authenticated;
grant select on public.product_lots to authenticated;
grant insert (tenant_id, product_id, lot_number, initial_quantity, received_on, opened_on, expires_on, location)
  on public.product_lots to authenticated;
grant update (received_on, opened_on, expires_on, location)
  on public.product_lots to authenticated;

create policy product_lots_select_tenant_member
  on public.product_lots
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = product_lots.tenant_id
        and membership.user_id = (select auth.uid())
    )
  );

create policy product_lots_insert_tenant_member
  on public.product_lots
  for insert
  to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = product_lots.tenant_id
        and membership.user_id = (select auth.uid())
    )
  );

create policy product_lots_update_tenant_member
  on public.product_lots
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = product_lots.tenant_id
        and membership.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = product_lots.tenant_id
        and membership.user_id = (select auth.uid())
    )
  );
