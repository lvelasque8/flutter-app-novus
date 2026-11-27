-- Novus · Esquema remoto de solo lectura
-- Pegar completo en Supabase → SQL Editor y ejecutar una sola vez.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Negocio y miembros
-- ---------------------------------------------------------------------------
create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null default '',
  owner_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_members (
  business_id uuid not null references public.businesses (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'owner',
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

-- ¿El usuario actual pertenece al negocio?
create or replace function public.is_member(p_business uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.business_members m
    where m.business_id = p_business
      and m.user_id = auth.uid()
  );
$$;

-- Devuelve el negocio del usuario y lo crea la primera vez.
create or replace function public.ensure_business(p_name text default '')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business uuid;
  v_name text;
begin
  if auth.uid() is null then
    raise exception 'Sesión no iniciada';
  end if;

  select m.business_id
    into v_business
    from public.business_members m
   where m.user_id = auth.uid()
   order by m.created_at asc
   limit 1;

  v_name := nullif(btrim(coalesce(p_name, '')), '');

  if v_business is null then
    insert into public.businesses (name, owner_id)
    values (coalesce(v_name, 'Mi negocio'), auth.uid())
    returning id into v_business;

    insert into public.business_members (business_id, user_id, role)
    values (v_business, auth.uid(), 'owner');
  elsif v_name is not null then
    update public.businesses
       set name = v_name,
           updated_at = now()
     where id = v_business
       and name <> v_name;
  end if;

  return v_business;
end;
$$;

-- ---------------------------------------------------------------------------
-- Espejo de las tablas locales (las fechas se guardan como texto ISO)
-- ---------------------------------------------------------------------------
create table if not exists public.products (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  name text not null default '',
  sku text,
  barcode text,
  category text,
  price double precision not null default 0,
  cost double precision not null default 0,
  stock integer not null default 0,
  min_stock integer not null default 0,
  tax_exempt integer not null default 0,
  active integer not null default 1,
  created_at text not null default '',
  updated_at text not null default '',
  primary key (business_id, id)
);

create table if not exists public.customers (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  name text not null default '',
  document text,
  phone text,
  address text,
  notes text,
  credit_limit double precision not null default 0,
  created_at text not null default '',
  primary key (business_id, id)
);

create table if not exists public.cash_sessions (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  opened_at text not null default '',
  closed_at text,
  opening_bs double precision not null default 0,
  opening_usd double precision not null default 0,
  counted_bs double precision,
  counted_usd double precision,
  expected_bs double precision,
  expected_usd double precision,
  difference_bs double precision,
  difference_usd double precision,
  notes text,
  status text not null default 'abierta',
  primary key (business_id, id)
);

create table if not exists public.sales (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  number text not null default '',
  customer_id text,
  customer_name text,
  subtotal double precision not null default 0,
  discount double precision not null default 0,
  tax double precision not null default 0,
  total double precision not null default 0,
  rate double precision not null default 0,
  total_bs double precision not null default 0,
  payment_method text not null default '',
  reference text,
  status text not null default 'pagada',
  cash_session_id text,
  note text,
  cancelled integer not null default 0,
  cancelled_at text,
  cancel_reason text,
  refunded double precision not null default 0,
  refunded_bs double precision not null default 0,
  created_at text not null default '',
  primary key (business_id, id)
);

create table if not exists public.sale_items (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  sale_id text not null,
  product_id text,
  name text not null default '',
  price double precision not null default 0,
  unit_cost double precision not null default 0,
  quantity integer not null default 0,
  subtotal double precision not null default 0,
  primary key (business_id, id)
);

create table if not exists public.payments (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  sale_id text not null,
  method text not null default '',
  amount double precision not null default 0,
  amount_bs double precision not null default 0,
  reference text,
  created_at text not null default '',
  primary key (business_id, id)
);

create table if not exists public.accounts (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  customer_id text not null,
  sale_id text,
  total double precision not null default 0,
  paid double precision not null default 0,
  status text not null default 'pendiente',
  due_date text,
  last_reminder_at text,
  cancelled integer not null default 0,
  created_at text not null default '',
  primary key (business_id, id)
);

create table if not exists public.account_payments (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  account_id text not null,
  amount double precision not null default 0,
  amount_bs double precision not null default 0,
  method text not null default '',
  note text,
  cash_session_id text,
  created_at text not null default '',
  primary key (business_id, id)
);

create table if not exists public.inventory_movements (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  product_id text not null,
  type text not null default '',
  quantity integer not null default 0,
  reference text,
  created_at text not null default '',
  primary key (business_id, id)
);

create table if not exists public.sale_returns (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  sale_id text not null,
  method text not null default '',
  total double precision not null default 0,
  total_bs double precision not null default 0,
  rate double precision not null default 0,
  reason text,
  cash_session_id text,
  created_at text not null default '',
  primary key (business_id, id)
);

create table if not exists public.sale_return_items (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id text not null,
  return_id text not null,
  sale_item_id text not null,
  product_id text,
  name text not null default '',
  price double precision not null default 0,
  quantity integer not null default 0,
  subtotal double precision not null default 0,
  primary key (business_id, id)
);

create table if not exists public.business_settings (
  business_id uuid not null references public.businesses (id) on delete cascade,
  key text not null,
  value text not null default '',
  primary key (business_id, key)
);

create table if not exists public.sync_devices (
  business_id uuid not null references public.businesses (id) on delete cascade,
  device_id text not null,
  app_version text not null default '',
  last_sync_at text not null default '',
  pending integer not null default 0,
  primary key (business_id, device_id)
);

create index if not exists idx_remote_sales_created
  on public.sales (business_id, created_at desc);
create index if not exists idx_remote_sale_items_sale
  on public.sale_items (business_id, sale_id);
create index if not exists idx_remote_accounts_status
  on public.accounts (business_id, status);
create index if not exists idx_remote_products_active
  on public.products (business_id, active);
create index if not exists idx_remote_cash_opened
  on public.cash_sessions (business_id, opened_at desc);

-- ---------------------------------------------------------------------------
-- Seguridad por fila: cada usuario solo ve su negocio
-- ---------------------------------------------------------------------------
alter table public.businesses enable row level security;
alter table public.business_members enable row level security;

drop policy if exists businesses_read on public.businesses;
create policy businesses_read on public.businesses
  for select to authenticated
  using (public.is_member(id));

drop policy if exists members_read on public.business_members;
create policy members_read on public.business_members
  for select to authenticated
  using (user_id = auth.uid());

do $$
declare
  t text;
  tables text[] := array[
    'products',
    'customers',
    'cash_sessions',
    'sales',
    'sale_items',
    'payments',
    'accounts',
    'account_payments',
    'inventory_movements',
    'sale_returns',
    'sale_return_items',
    'business_settings',
    'sync_devices'
  ];
begin
  foreach t in array tables loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_read', t);
    execute format('drop policy if exists %I on public.%I', t || '_insert', t);
    execute format('drop policy if exists %I on public.%I', t || '_update', t);
    execute format('drop policy if exists %I on public.%I', t || '_delete', t);

    execute format(
      'create policy %I on public.%I for select to authenticated using (public.is_member(business_id))',
      t || '_read', t
    );
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (public.is_member(business_id))',
      t || '_insert', t
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using (public.is_member(business_id)) with check (public.is_member(business_id))',
      t || '_update', t
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated using (public.is_member(business_id))',
      t || '_delete', t
    );
  end loop;
end;
$$;

-- Permisos: la clave publicable no puede leer nada sin sesión.
revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public
  to authenticated;

revoke all on function public.is_member(uuid) from public;
revoke all on function public.ensure_business(text) from public;
grant execute on function public.is_member(uuid) to authenticated;
grant execute on function public.ensure_business(text) to authenticated;
