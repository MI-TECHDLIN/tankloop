-- Field photos are private evidence, never public QR content.
insert into storage.buckets (id, name, public)
values ('inspection-evidence', 'inspection-evidence', false)
on conflict (id) do update set public = false;

create policy "field members upload own evidence"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'inspection-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "field members update own evidence"
on storage.objects for update to authenticated
using (
  bucket_id = 'inspection-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'inspection-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "field members read own evidence"
on storage.objects for select to authenticated
using (
  bucket_id = 'inspection-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
);
