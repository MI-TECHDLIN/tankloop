-- Field photos are private evidence, never public QR content.
-- Ensure the inspection-evidence bucket exists and is private.
do $$
begin
  if not exists (select 1 from storage.buckets where id = 'inspection-evidence') then
    insert into storage.buckets (id, name, public)
    values ('inspection-evidence', 'inspection-evidence', false);
  else
    update storage.buckets set public = false where id = 'inspection-evidence';
  end if;
end $$;

create policy "field members upload own evidence"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'inspection-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.status = 'active'
      and (m.valid_until is null or m.valid_until > now())
      and m.role in ('field', 'manager', 'admin')
  )
);

create policy "field members update own evidence"
on storage.objects for update to authenticated
using (
  bucket_id = 'inspection-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.status = 'active'
      and (m.valid_until is null or m.valid_until > now())
      and m.role in ('field', 'manager', 'admin')
  )
)
with check (
  bucket_id = 'inspection-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.status = 'active'
      and (m.valid_until is null or m.valid_until > now())
      and m.role in ('field', 'manager', 'admin')
  )
);

create policy "field members read own evidence"
on storage.objects for select to authenticated
using (
  bucket_id = 'inspection-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.status = 'active'
      and (m.valid_until is null or m.valid_until > now())
      and m.role in ('field', 'manager', 'admin')
  )
);