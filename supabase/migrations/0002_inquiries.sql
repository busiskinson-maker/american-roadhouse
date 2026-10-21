-- Website inquiries (room bookings, table reservations, contact messages).
-- Visitors submit through public.submit_inquiry(); only staff can read or update them.

create type public.inquiry_kind   as enum ('booking', 'table', 'message');
create type public.inquiry_status as enum ('new', 'contacted', 'closed');

create table public.inquiries (
  id          uuid primary key default gen_random_uuid(),
  kind        public.inquiry_kind not null,
  full_name   text not null check (char_length(btrim(full_name)) between 2 and 80),
  phone       text not null check (phone ~ '^[0-9+() -]{7,24}$'),
  email       text check (email is null or char_length(email) <= 120),
  details     jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object'),
  status      public.inquiry_status not null default 'new',
  staff_notes text check (staff_notes is null or char_length(staff_notes) <= 500),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index inquiries_status_idx on public.inquiries (status, created_at desc);

create trigger touch_inquiries before update on public.inquiries
  for each row execute function public.touch_updated_at();

create function public.submit_inquiry(
  p_kind      text,
  p_full_name text,
  p_phone     text,
  p_email     text,
  p_details   jsonb
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_name    text := btrim(coalesce(p_full_name, ''));
  v_phone   text := btrim(coalesce(p_phone, ''));
  v_email   text := nullif(btrim(coalesce(p_email, '')), '');
  v_details jsonb;
begin
  if p_kind not in ('booking', 'table', 'message') then
    raise exception 'INVALID_KIND: Unknown request type.';
  end if;
  if char_length(v_name) not between 2 and 80 then
    raise exception 'INVALID_NAME: Please enter your name.';
  end if;
  if v_phone !~ '^[0-9+() -]{7,24}$' then
    raise exception 'INVALID_PHONE: Please enter a valid phone number.';
  end if;
  if v_email is not null and (char_length(v_email) > 120 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') then
    raise exception 'INVALID_EMAIL: Please enter a valid email address.';
  end if;
  if p_details is null or jsonb_typeof(p_details) <> 'object' then
    p_details := '{}'::jsonb;
  end if;
  -- Basic flood protection for an unauthenticated endpoint.
  if (select count(*) from public.inquiries where created_at > now() - interval '10 minutes') >= 40 then
    raise exception 'RATE_LIMIT: Too many requests right now. Please call us at 0915 875 4860.';
  end if;

  -- Keep only known fields, as trimmed text of reasonable length.
  select coalesce(jsonb_object_agg(key, left(btrim(value), 500)), '{}'::jsonb) into v_details
  from jsonb_each_text(p_details)
  where key in ('check_in', 'check_out', 'guests', 'room_preference', 'date', 'time',
                'party_size', 'special_request', 'notes', 'message')
    and btrim(value) <> '';

  insert into public.inquiries (kind, full_name, phone, email, details)
  values (p_kind::public.inquiry_kind, v_name, v_phone, v_email, v_details);
end $$;

revoke execute on function public.submit_inquiry(text, text, text, text, jsonb) from public;
grant  execute on function public.submit_inquiry(text, text, text, text, jsonb) to anon, authenticated;

revoke all on public.inquiries from anon, authenticated;
grant select, delete on public.inquiries to authenticated;
grant update (status, staff_notes) on public.inquiries to authenticated;

alter table public.inquiries enable row level security;
create policy inquiries_select on public.inquiries for select using (public.is_staff());
create policy inquiries_update on public.inquiries for update
  using (public.is_staff()) with check (public.is_staff());
create policy inquiries_delete on public.inquiries for delete using (public.is_admin());

alter publication supabase_realtime add table public.inquiries;
