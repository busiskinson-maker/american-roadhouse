-- The public rooms page needs to know when a room has been switched off (to grey out its button
-- and show "Not available yet"). Room names and rates are public information, so every row is
-- readable; only admins can change them (unchanged).
drop policy if exists room_rates_select on public.room_rates;
create policy room_rates_select on public.room_rates for select using (true);
