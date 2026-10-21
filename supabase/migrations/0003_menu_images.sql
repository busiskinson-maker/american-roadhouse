-- Photo uploads for menu items and rooms.
-- Public bucket (customers load photos by URL); only active staff can add, change or remove files.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('menu-images', 'menu-images', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "staff read menu images" on storage.objects for select to authenticated
  using (bucket_id = 'menu-images' and public.is_staff());

create policy "staff upload menu images" on storage.objects for insert to authenticated
  with check (bucket_id = 'menu-images' and public.is_staff());

create policy "staff update menu images" on storage.objects for update to authenticated
  using (bucket_id = 'menu-images' and public.is_staff())
  with check (bucket_id = 'menu-images' and public.is_staff());

create policy "staff delete menu images" on storage.objects for delete to authenticated
  using (bucket_id = 'menu-images' and public.is_staff());
