-- SHADE Lot 1A.1 — tenants and tenant memberships
-- Local migration only. No remote project is linked by this file.

create extension if not exists pgcrypto;

create schema if not exists app_private;
revoke all on schema app_private from public;

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) > 0),
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.tenant_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (char_length(btrim(role)) > 0),
  created_at timestamptz not null default now(),
  constraint tenant_memberships_tenant_user_unique unique (tenant_id, user_id)
);

create index tenant_memberships_user_id_idx
  on public.tenant_memberships(user_id);

alter table public.tenants enable row level security;
alter table public.tenant_memberships enable row level security;

revoke all on public.tenants from anon, authenticated;
revoke all on public.tenant_memberships from anon, authenticated;

grant select on public.tenants to authenticated;
grant insert (name) on public.tenants to authenticated;
grant select on public.tenant_memberships to authenticated;

create policy tenants_select_member_or_creator
  on public.tenants
  for select
  to authenticated
  using (
    created_by = (select auth.uid())
    or exists (
      select 1
      from public.tenant_memberships membership
      where membership.tenant_id = tenants.id
        and membership.user_id = (select auth.uid())
    )
  );

create policy tenants_insert_own
  on public.tenants
  for insert
  to authenticated
  with check (created_by = (select auth.uid()));

create policy tenant_memberships_select_own
  on public.tenant_memberships
  for select
  to authenticated
  using (user_id = (select auth.uid()));

-- Tenant creation bootstraps the creator membership atomically.
-- Membership management/invitations are intentionally outside Lot 1A.
create or replace function app_private.create_creator_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.tenant_memberships (tenant_id, user_id)
  values (new.id, new.created_by);
  return new;
end;
$$;

revoke all on function app_private.create_creator_membership() from public, anon, authenticated;

create trigger tenants_create_creator_membership_after_insert
after insert on public.tenants
for each row execute function app_private.create_creator_membership();
