-- SHADE Lot 1A.4 — immutable stock movements and current stock calculation

create schema if not exists app_private;
revoke all on schema app_private from public;

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  product_lot_id uuid not null,
  movement_type text not null check (
    movement_type in ('initial', 'receipt', 'issue', 'adjustment', 'loss')
  ),
  quantity_delta numeric(14,4) not null check (quantity_delta <> 0),
  reason text,
  occurred_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint stock_movements_lot_fk
    foreign key (tenant_id, product_lot_id)
    references public.product_lots(tenant_id, id)
    on delete restrict,
  constraint stock_movements_sign_check check (
    (movement_type = 'initial' and quantity_delta > 0)
    or (movement_type = 'receipt' and quantity_delta > 0)
    or (movement_type = 'issue' and quantity_delta < 0)
    or (movement_type = 'loss' and quantity_delta < 0)
    or (movement_type = 'adjustment' and quantity_delta <> 0)
  ),
  constraint stock_movements_reason_check check (
    movement_type not in ('adjustment', 'loss')
    or (reason is not null and char_length(btrim(reason)) > 0)
  )
);

create index stock_movements_tenant_lot_occurred_idx
  on public.stock_movements(tenant_id, product_lot_id, occurred_at desc);

create unique index stock_movements_one_initial_per_lot_idx
  on public.stock_movements(product_lot_id)
  where movement_type = 'initial';

alter table public.stock_movements enable row level security;

revoke all on public.stock_movements from anon, authenticated;
grant select on public.stock_movements to authenticated;
grant insert (tenant_id, product_lot_id, movement_type, quantity_delta, reason)
  on public.stock_movements to authenticated;

create policy stock_movements_select_tenant_member
  on public.stock_movements
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = stock_movements.tenant_id
        and membership.user_id = (select auth.uid())
    )
  );

create policy stock_movements_insert_tenant_member
  on public.stock_movements
  for insert
  to authenticated
  with check (
    movement_type <> 'initial'
    and created_by = (select auth.uid())
    and exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = stock_movements.tenant_id
        and membership.user_id = (select auth.uid())
    )
  );

-- Serialise movements per lot and reject any mutation that would make stock negative.
create or replace function app_private.ensure_non_negative_stock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_quantity numeric(14,4);
begin
  perform 1
  from public.product_lots lot
  where lot.tenant_id = new.tenant_id
    and lot.id = new.product_lot_id
  for update;

  if not found then
    raise exception 'Unknown product lot for tenant'
      using errcode = '23503';
  end if;

  select coalesce(sum(movement.quantity_delta), 0)
    into current_quantity
  from public.stock_movements movement
  where movement.tenant_id = new.tenant_id
    and movement.product_lot_id = new.product_lot_id;

  if current_quantity + new.quantity_delta < 0 then
    raise exception 'Stock movement would make current stock negative'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function app_private.ensure_non_negative_stock() from public, anon, authenticated;

create trigger stock_movements_non_negative_before_insert
before insert on public.stock_movements
for each row execute function app_private.ensure_non_negative_stock();

-- Initial quantity becomes the first immutable stock movement.
create or replace function app_private.create_initial_stock_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.stock_movements (
    tenant_id,
    product_lot_id,
    movement_type,
    quantity_delta,
    reason,
    occurred_at,
    created_by
  ) values (
    new.tenant_id,
    new.id,
    'initial',
    new.initial_quantity,
    'Initial quantity',
    new.created_at,
    new.created_by
  );

  return new;
end;
$$;

revoke all on function app_private.create_initial_stock_movement() from public, anon, authenticated;

-- Backfill safely if this migration is applied after local lot fixtures already exist.
insert into public.stock_movements (
  tenant_id,
  product_lot_id,
  movement_type,
  quantity_delta,
  reason,
  occurred_at,
  created_by
)
select
  lot.tenant_id,
  lot.id,
  'initial',
  lot.initial_quantity,
  'Initial quantity',
  lot.created_at,
  lot.created_by
from public.product_lots lot
where not exists (
  select 1
  from public.stock_movements movement
  where movement.product_lot_id = lot.id
    and movement.movement_type = 'initial'
);

create trigger product_lots_create_initial_movement_after_insert
after insert on public.product_lots
for each row execute function app_private.create_initial_stock_movement();

-- Movement history is append-only. Corrections are new movements.
create or replace function app_private.reject_stock_movement_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Stock movements are immutable; create a correction movement instead'
    using errcode = '55000';
end;
$$;

revoke all on function app_private.reject_stock_movement_mutation() from public, anon, authenticated;

create trigger stock_movements_reject_update_delete
before update or delete on public.stock_movements
for each row execute function app_private.reject_stock_movement_mutation();

create or replace view public.product_lot_stock
with (security_invoker = true)
as
select
  lot.tenant_id,
  lot.id as product_lot_id,
  lot.product_id,
  lot.lot_number,
  lot.initial_quantity,
  product.name as product_name,
  product.product_type,
  product.brand,
  product.reference,
  product.unit,
  lot.received_on,
  lot.opened_on,
  lot.expires_on,
  lot.location,
  coalesce(sum(movement.quantity_delta), 0)::numeric(14,4) as current_quantity
from public.product_lots lot
join public.products product
  on product.tenant_id = lot.tenant_id
 and product.id = lot.product_id
left join public.stock_movements movement
  on movement.tenant_id = lot.tenant_id
 and movement.product_lot_id = lot.id
group by
  lot.tenant_id,
  lot.id,
  lot.product_id,
  lot.lot_number,
  lot.initial_quantity,
  product.name,
  product.product_type,
  product.brand,
  product.reference,
  product.unit,
  lot.received_on,
  lot.opened_on,
  lot.expires_on,
  lot.location;

revoke all on public.product_lot_stock from anon, authenticated;
grant select on public.product_lot_stock to authenticated;
