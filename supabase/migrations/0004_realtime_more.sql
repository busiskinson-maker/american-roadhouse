-- Let the staff dashboard receive live changes for discounts and the price history too.
-- (RLS still applies: only active staff can read these tables, so only they receive the events.)
do $$
declare t text;
begin
  foreach t in array array['discounts', 'price_history']
  loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
