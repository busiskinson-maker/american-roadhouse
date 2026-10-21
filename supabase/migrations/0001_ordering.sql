-- American Roadhouse: online ordering schema, security policies, and realtime.
-- Run once on a fresh Supabase project (SQL Editor, or `supabase db push`).
-- See docs/SUPABASE_SETUP.md for the full setup walkthrough.

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------
create type public.staff_role    as enum ('employee', 'admin');
create type public.order_status  as enum ('pending', 'preparing', 'ready', 'completed', 'cancelled');
create type public.discount_type as enum ('percent', 'fixed');

-- ---------------------------------------------------------------------------
-- Staff profiles. A row here is what makes an auth user "staff".
-- Customers (anonymous or otherwise) never get a row, and nobody can create
-- one from the browser; admins use public.admin_set_staff_role().
-- ---------------------------------------------------------------------------
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text,
  full_name  text,
  role       public.staff_role not null default 'employee',
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and is_active)
$$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and is_active and role = 'admin')
$$;

-- ---------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------
create table public.categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(btrim(name)) between 1 and 80),
  slug       text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.menu_items (
  id           uuid primary key default gen_random_uuid(),
  category_id  uuid references public.categories (id) on delete restrict,
  name         text not null check (char_length(btrim(name)) between 1 and 120),
  description  text not null default '' check (char_length(description) <= 500),
  price        numeric(10,2) not null check (price > 0 and price <= 1000000),
  image_url    text check (image_url is null or char_length(image_url) <= 500),
  is_visible   boolean not null default true,   -- hidden items are not shown to customers
  is_available boolean not null default true,   -- unavailable items show as "Sold out"
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index menu_items_category_idx on public.menu_items (category_id, sort_order);

create table public.room_rates (
  id              uuid primary key default gen_random_uuid(),
  name            text not null check (char_length(btrim(name)) between 1 and 120),
  description     text not null default '' check (char_length(description) <= 500),
  price_per_night numeric(10,2) not null check (price_per_night > 0 and price_per_night <= 1000000),
  image_url       text,
  is_active       boolean not null default true,
  sort_order      integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.addons (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(btrim(name)) between 1 and 120),
  description text not null default '' check (char_length(description) <= 500),
  price       numeric(10,2) not null check (price > 0 and price <= 1000000),
  unit        text not null default 'each' check (char_length(unit) <= 30),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.discounts (
  id           uuid primary key default gen_random_uuid(),
  code         text not null check (code ~ '^[A-Za-z0-9_-]{3,30}$'),
  description  text not null default '' check (char_length(description) <= 200),
  type         public.discount_type not null,
  value        numeric(10,2) not null check (value > 0 and value <= 1000000),
  min_subtotal numeric(10,2) not null default 0 check (min_subtotal >= 0),
  is_active    boolean not null default true,
  starts_at    timestamptz,
  ends_at      timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  check (type <> 'percent' or value <= 100),
  check (ends_at is null or starts_at is null or ends_at > starts_at)
);
create unique index discounts_code_key on public.discounts (lower(code));

-- ---------------------------------------------------------------------------
-- Customers and orders (written only through public.place_order)
-- ---------------------------------------------------------------------------
create table public.customers (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null unique references auth.users (id) on delete cascade,
  name       text not null,
  phone      text not null,
  email      text,
  created_at timestamptz not null default now()
);

create table public.orders (
  id                uuid primary key default gen_random_uuid(),
  order_number      bigint generated always as identity (start with 1001),
  user_id           uuid references auth.users (id) on delete set null,
  customer_id       uuid references public.customers (id) on delete set null,
  customer_name     text not null,
  customer_phone    text not null,
  order_type        text not null check (order_type in ('pickup', 'dine_in', 'room_delivery')),
  room_number       text,
  notes             text check (notes is null or char_length(notes) <= 500),
  staff_notes       text check (staff_notes is null or char_length(staff_notes) <= 500),
  status            public.order_status not null default 'pending',
  subtotal          numeric(12,2) not null check (subtotal >= 0),
  discount_code     text,
  discount_total    numeric(12,2) not null default 0 check (discount_total >= 0),
  total             numeric(12,2) not null check (total >= 0),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  status_updated_at timestamptz,
  status_updated_by uuid references auth.users (id) on delete set null
);
create index orders_user_idx    on public.orders (user_id, created_at desc);
create index orders_status_idx  on public.orders (status, created_at desc);

create table public.order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references public.orders (id) on delete cascade,
  menu_item_id uuid references public.menu_items (id) on delete set null,
  item_name    text not null,
  unit_price   numeric(10,2) not null check (unit_price > 0),
  quantity     integer not null check (quantity between 1 and 99),
  line_total   numeric(12,2) not null check (line_total > 0)
);
create index order_items_order_idx on public.order_items (order_id);

-- ---------------------------------------------------------------------------
-- Price history (append-only audit trail, written by trigger only)
-- ---------------------------------------------------------------------------
create table public.price_history (
  id               bigint generated always as identity primary key,
  table_name       text not null,
  record_id        uuid not null,
  record_name      text,
  field            text not null,
  old_price        numeric(10,2),
  new_price        numeric(10,2) not null,
  changed_by       uuid references auth.users (id) on delete set null,
  changed_by_email text,
  changed_at       timestamptz not null default now()
);
create index price_history_changed_idx on public.price_history (changed_at desc);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
create function public.touch_updated_at() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger touch_categories  before update on public.categories  for each row execute function public.touch_updated_at();
create trigger touch_menu_items  before update on public.menu_items  for each row execute function public.touch_updated_at();
create trigger touch_room_rates  before update on public.room_rates  for each row execute function public.touch_updated_at();
create trigger touch_addons      before update on public.addons      for each row execute function public.touch_updated_at();
create trigger touch_discounts   before update on public.discounts   for each row execute function public.touch_updated_at();

-- Records who changed a price column and when. tg_argv[0] = column name.
create function public.log_price_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  col   text  := tg_argv[0];
  j_new jsonb := to_jsonb(new);
  j_old jsonb;
begin
  if tg_op = 'UPDATE' then
    j_old := to_jsonb(old);
    if (j_old ->> col) is not distinct from (j_new ->> col) then
      return new;
    end if;
  end if;
  insert into public.price_history
    (table_name, record_id, record_name, field, old_price, new_price, changed_by, changed_by_email)
  values
    (tg_table_name, (j_new ->> 'id')::uuid, coalesce(j_new ->> 'name', j_new ->> 'code'), col,
     (j_old ->> col)::numeric, (j_new ->> col)::numeric, auth.uid(), auth.jwt() ->> 'email');
  return new;
end $$;

create trigger log_price_menu_items after insert or update on public.menu_items
  for each row execute function public.log_price_change('price');
create trigger log_price_room_rates after insert or update on public.room_rates
  for each row execute function public.log_price_change('price_per_night');
create trigger log_price_addons after insert or update on public.addons
  for each row execute function public.log_price_change('price');
create trigger log_price_discounts after insert or update on public.discounts
  for each row execute function public.log_price_change('value');

-- Stamp status changes; only admins may reopen a completed/cancelled order.
create function public.guard_order_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    if old.status in ('completed', 'cancelled') and not public.is_admin() then
      raise exception 'LOCKED: Only an administrator can reopen a % order.', old.status;
    end if;
    new.status_updated_at := now();
    new.status_updated_by := auth.uid();
  end if;
  new.updated_at := now();
  return new;
end $$;

create trigger guard_orders before update on public.orders
  for each row execute function public.guard_order_update();

-- ---------------------------------------------------------------------------
-- Ordering functions. Customers cannot insert into orders directly: prices
-- are always recomputed here from the live catalog, so a tampered browser
-- cannot underpay.
-- ---------------------------------------------------------------------------
create function public._price_cart(p_items jsonb, p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_code     text := nullif(btrim(coalesce(p_code, '')), '');
  v_subtotal numeric(12,2);
  v_bad      text;
  v_lines    jsonb;
  v_disc     public.discounts;
  v_discount numeric(12,2) := 0;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) not between 1 and 40 then
    raise exception 'EMPTY_CART: Your cart is empty or invalid.';
  end if;
  if exists (select 1 from jsonb_to_recordset(p_items) as x(id uuid, qty int)
             where x.id is null or x.qty is null or x.qty < 1 or x.qty > 50) then
    raise exception 'INVALID_QTY: Quantities must be between 1 and 50.';
  end if;

  with cart as (
    select x.id, sum(x.qty)::int as qty
    from jsonb_to_recordset(p_items) as x(id uuid, qty int) group by x.id
  ), priced as (
    select cart.id, cart.qty, m.name, m.price,
           (m.id is not null and m.is_visible and m.is_available and coalesce(c.is_visible, true)) as ok
    from cart
    left join public.menu_items m on m.id = cart.id
    left join public.categories c on c.id = m.category_id
  )
  select coalesce(sum(price * qty) filter (where ok), 0),
         string_agg(coalesce(name, 'An item'), ', ') filter (where not ok),
         jsonb_agg(jsonb_build_object('id', id, 'name', name, 'price', price, 'qty', qty,
                                      'line_total', price * qty)) filter (where ok)
    into v_subtotal, v_bad, v_lines
  from priced;

  if v_bad is not null then
    raise exception 'ITEM_UNAVAILABLE: % is no longer available. Please update your cart.', v_bad;
  end if;

  if v_code is not null then
    select * into v_disc from public.discounts d
    where lower(d.code) = lower(v_code) and d.is_active
      and (d.starts_at is null or d.starts_at <= now())
      and (d.ends_at   is null or d.ends_at   >= now());
    if not found then
      raise exception 'INVALID_DISCOUNT: That discount code is not valid.';
    end if;
    if v_subtotal < v_disc.min_subtotal then
      raise exception 'DISCOUNT_MIN: This code needs a minimum order of %.', v_disc.min_subtotal;
    end if;
    v_discount := case when v_disc.type = 'percent'
                       then round(v_subtotal * v_disc.value / 100, 2)
                       else least(v_disc.value, v_subtotal) end;
  end if;

  return jsonb_build_object(
    'subtotal', v_subtotal, 'discount_total', v_discount, 'total', v_subtotal - v_discount,
    'discount_code', case when v_code is null then null else v_disc.code end,
    'lines', v_lines);
end $$;

create function public.quote_order(p_items jsonb, p_discount_code text default null) returns jsonb
language sql security definer set search_path = public as $$
  select public._price_cart(p_items, p_discount_code) - 'lines'
$$;

create function public.place_order(
  p_customer_name text,
  p_phone         text,
  p_email         text,
  p_order_type    text,
  p_room_number   text,
  p_notes         text,
  p_discount_code text,
  p_items         jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid      uuid := auth.uid();
  v_name     text := btrim(coalesce(p_customer_name, ''));
  v_phone    text := btrim(coalesce(p_phone, ''));
  v_email    text := nullif(btrim(coalesce(p_email, '')), '');
  v_room     text := nullif(btrim(coalesce(p_room_number, '')), '');
  v_notes    text := nullif(btrim(coalesce(p_notes, '')), '');
  v_priced   jsonb;
  v_customer uuid;
  v_order    public.orders;
begin
  if v_uid is null then
    raise exception 'NOT_SIGNED_IN: Please try again.';
  end if;
  if char_length(v_name) not between 2 and 80 then
    raise exception 'INVALID_NAME: Please enter your name (2-80 characters).';
  end if;
  if v_phone !~ '^[0-9+() -]{7,20}$' then
    raise exception 'INVALID_PHONE: Please enter a valid phone number.';
  end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'INVALID_EMAIL: Please enter a valid email address.';
  end if;
  if p_order_type not in ('pickup', 'dine_in', 'room_delivery') then
    raise exception 'INVALID_TYPE: Please choose how you would like to receive your order.';
  end if;
  if p_order_type = 'room_delivery' and (v_room is null or char_length(v_room) > 20) then
    raise exception 'INVALID_ROOM: Please enter your room number.';
  end if;
  if v_notes is not null and char_length(v_notes) > 500 then
    raise exception 'INVALID_NOTES: Notes must be 500 characters or fewer.';
  end if;
  if (select count(*) from public.orders where user_id = v_uid and status = 'pending') >= 5 then
    raise exception 'TOO_MANY_PENDING: You already have several pending orders. Please wait for the kitchen to confirm them.';
  end if;

  v_priced := public._price_cart(p_items, p_discount_code);

  insert into public.customers (user_id, name, phone, email)
  values (v_uid, v_name, v_phone, v_email)
  on conflict (user_id) do update set name = excluded.name, phone = excluded.phone, email = excluded.email
  returning id into v_customer;

  insert into public.orders
    (user_id, customer_id, customer_name, customer_phone, order_type, room_number, notes,
     subtotal, discount_code, discount_total, total)
  values
    (v_uid, v_customer, v_name, v_phone, p_order_type,
     case when p_order_type = 'room_delivery' then v_room end, v_notes,
     (v_priced ->> 'subtotal')::numeric, v_priced ->> 'discount_code',
     (v_priced ->> 'discount_total')::numeric, (v_priced ->> 'total')::numeric)
  returning * into v_order;

  insert into public.order_items (order_id, menu_item_id, item_name, unit_price, quantity, line_total)
  select v_order.id, (l ->> 'id')::uuid, l ->> 'name', (l ->> 'price')::numeric,
         (l ->> 'qty')::int, (l ->> 'line_total')::numeric
  from jsonb_array_elements(v_priced -> 'lines') l;

  return jsonb_build_object('order_id', v_order.id, 'order_number', v_order.order_number,
                            'total', v_order.total, 'status', v_order.status);
end $$;

-- Admin-only staff management (the browser can never write profiles directly).
create function public.admin_set_staff_role(p_email text, p_role public.staff_role, p_active boolean default true)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_user uuid;
begin
  if not public.is_admin() then
    raise exception 'FORBIDDEN: Administrators only.';
  end if;
  select id into v_user from auth.users where lower(email) = lower(btrim(p_email));
  if not found then
    raise exception 'USER_NOT_FOUND: Create this user under Authentication > Users first.';
  end if;
  if v_user = auth.uid() and (p_role <> 'admin' or not p_active) then
    raise exception 'SELF_CHANGE: You cannot demote or deactivate yourself.';
  end if;
  insert into public.profiles (id, email, role, is_active)
  values (v_user, lower(btrim(p_email)), p_role, p_active)
  on conflict (id) do update set role = excluded.role, is_active = excluded.is_active, email = excluded.email;
end $$;

revoke execute on function public._price_cart(jsonb, text) from public, anon, authenticated;
revoke execute on function public.quote_order(jsonb, text) from public, anon;
revoke execute on function public.place_order(text, text, text, text, text, text, text, jsonb) from public, anon;
revoke execute on function public.admin_set_staff_role(text, public.staff_role, boolean) from public, anon;
revoke execute on function public.log_price_change() from public, anon, authenticated;
revoke execute on function public.guard_order_update() from public, anon, authenticated;
grant execute on function public.quote_order(jsonb, text) to anon, authenticated;
grant execute on function public.place_order(text, text, text, text, text, text, text, jsonb) to authenticated;
grant execute on function public.admin_set_staff_role(text, public.staff_role, boolean) to authenticated;
grant execute on function public.is_staff(), public.is_admin() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Table privileges (RLS below narrows these further)
-- ---------------------------------------------------------------------------
revoke all on public.profiles, public.categories, public.menu_items, public.room_rates, public.addons,
              public.discounts, public.customers, public.orders, public.order_items, public.price_history
  from anon, authenticated;

grant select on public.categories, public.menu_items, public.room_rates, public.addons to anon;
grant select on public.profiles, public.categories, public.menu_items, public.room_rates, public.addons,
                public.discounts, public.customers, public.orders, public.order_items, public.price_history
  to authenticated;
grant insert, update, delete on public.categories, public.menu_items, public.room_rates, public.addons,
                                public.discounts to authenticated;
grant update (status, staff_notes) on public.orders to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.categories    enable row level security;
alter table public.menu_items    enable row level security;
alter table public.room_rates    enable row level security;
alter table public.addons        enable row level security;
alter table public.discounts     enable row level security;
alter table public.customers     enable row level security;
alter table public.orders        enable row level security;
alter table public.order_items   enable row level security;
alter table public.price_history enable row level security;

-- profiles: see your own row; admins see everyone. Writes only via admin_set_staff_role().
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or public.is_admin());

-- categories + menu items: public sees visible rows; staff (employee + admin) manage them.
create policy categories_select on public.categories for select using (is_visible or public.is_staff());
create policy categories_write  on public.categories for all
  using (public.is_staff()) with check (public.is_staff());

create policy menu_items_select on public.menu_items for select using (is_visible or public.is_staff());
create policy menu_items_write  on public.menu_items for all
  using (public.is_staff()) with check (public.is_staff());

-- rooms, add-ons, discounts: public sees active rooms/add-ons; only admins change them.
-- Discount codes are never readable by customers (they are checked inside place_order).
create policy room_rates_select on public.room_rates for select using (is_active or public.is_staff());
create policy room_rates_write  on public.room_rates for all
  using (public.is_admin()) with check (public.is_admin());

create policy addons_select on public.addons for select using (is_active or public.is_staff());
create policy addons_write  on public.addons for all
  using (public.is_admin()) with check (public.is_admin());

create policy discounts_select on public.discounts for select using (public.is_staff());
create policy discounts_write  on public.discounts for all
  using (public.is_admin()) with check (public.is_admin());

-- customers / orders / order items: owners read their own; staff read all; only staff update orders.
-- There are deliberately no insert/delete policies: orders are created by place_order().
create policy customers_select on public.customers for select
  using (user_id = auth.uid() or public.is_staff());

create policy orders_select on public.orders for select
  using (user_id = auth.uid() or public.is_staff());
create policy orders_update on public.orders for update
  using (public.is_staff()) with check (public.is_staff());

create policy order_items_select on public.order_items for select
  using (exists (select 1 from public.orders o
                 where o.id = order_id and (o.user_id = auth.uid() or public.is_staff())));

-- price history: staff read only; no client write policies (the trigger writes it).
create policy price_history_select on public.price_history for select using (public.is_staff());

-- ---------------------------------------------------------------------------
-- Realtime (RLS applies: staff receive every order, customers only their own)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['orders', 'menu_items', 'categories', 'room_rates', 'addons']
  loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
