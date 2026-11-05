-- Attachments are private, immutable observations linked to a scoped command.
update storage.buckets set file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg','image/png'] where id = 'inspection-evidence';

create table public.field_evidence (
  id uuid primary key,
  organization_id uuid not null,
  facility_id uuid not null,
  inspection_id uuid,
  work_order_id uuid,
  step public.work_order_state,
  question_id text,
  actor_id uuid not null references auth.users(id),
  client_event_id uuid not null,
  storage_path text not null unique,
  captured_at timestamptz not null,
  received_at timestamptz not null default now(),
  is_simulated boolean not null,
  check ((inspection_id is not null)::int + (work_order_id is not null)::int = 1),
  foreign key (organization_id,facility_id,inspection_id) references public.inspections(organization_id,facility_id,id),
  foreign key (organization_id,facility_id,work_order_id) references public.work_orders(organization_id,facility_id,id)
);
alter table public.field_evidence enable row level security;
revoke all on public.field_evidence from anon, authenticated;
grant select on public.field_evidence to authenticated;
create policy "members read scoped field evidence" on public.field_evidence for select to authenticated
using (private.has_membership(organization_id,facility_id,array['field','manager','admin']::public.member_role[]));

create table private.field_command_manifests (
  actor_id uuid not null,
  client_event_id uuid not null,
  manifest jsonb not null,
  primary key (actor_id,client_event_id)
);

create policy "members read linked evidence files" on storage.objects for select to authenticated
using (bucket_id = 'inspection-evidence' and exists (
  select 1 from public.field_evidence e where e.storage_path = name
    and private.has_membership(e.organization_id,e.facility_id,array['field','manager','admin']::public.member_role[])
));
-- Do not allow a retry to overwrite bytes after an observation was acknowledged.
drop policy "field members update own evidence" on storage.objects;

create function private.attach_field_evidence(p_org uuid,p_facility uuid,p_inspection uuid,p_order uuid,
  p_step public.work_order_state,p_event uuid,p_evidence jsonb,p_simulated boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare e jsonb;
begin
  if jsonb_typeof(p_evidence) is distinct from 'array' or jsonb_array_length(p_evidence) > 20 then
    raise invalid_parameter_value using message = 'At most 20 photos may accompany a command';
  end if;
  for e in select value from jsonb_array_elements(p_evidence) loop
    if e->>'path' is distinct from auth.uid()::text || '/inspections/' || (e->>'id') || '.jpg'
      or e->>'captured_at' is null
      or not exists (select 1 from storage.objects o where o.bucket_id = 'inspection-evidence' and o.name = e->>'path') then
      raise invalid_parameter_value using message = 'Upload the private evidence before submitting';
    end if;
    if p_inspection is not null and e->>'question_id' is not null and not exists (
      select 1 from public.inspections i join public.checklist_templates t on t.id = i.template_id,
        jsonb_array_elements(t.questions) q where i.id = p_inspection and q->>'id' = e->>'question_id'
    ) then raise invalid_parameter_value using message = 'Photo question does not belong to this checklist'; end if;
    insert into public.field_evidence(id,organization_id,facility_id,inspection_id,work_order_id,step,question_id,
      actor_id,client_event_id,storage_path,captured_at,received_at,is_simulated)
    values ((e->>'id')::uuid,p_org,p_facility,p_inspection,p_order,p_step,e->>'question_id',auth.uid(),p_event,
      e->>'path',(e->>'captured_at')::timestamptz,private.record_time(p_org),p_simulated);
  end loop;
end;
$$;
revoke all on function private.attach_field_evidence from public, anon, authenticated;

create function public.submit_inspection_with_evidence(p_event_id uuid,p_inspection_id uuid,p_expected_version integer,
  p_answers jsonb,p_notes text,p_observed_at timestamptz,p_evidence jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare item public.inspections; prior jsonb; receipt jsonb; had_receipt boolean;
begin
  select * into item from public.inspections where id = p_inspection_id for update;
  -- The existing RPC remains the authority for membership, assignee and version.
  select exists(select 1 from public.command_receipts where actor_id = auth.uid() and client_event_id = p_event_id) into had_receipt;
  receipt := public.submit_inspection(p_event_id,p_inspection_id,p_expected_version,p_answers,p_notes,p_observed_at);
  select manifest into prior from private.field_command_manifests where actor_id = auth.uid() and client_event_id = p_event_id;
  if found then
    if prior is distinct from p_evidence then raise unique_violation using message = 'Evidence changed for an acknowledged command'; end if;
    return receipt;
  end if;
  if had_receipt and p_evidence <> '[]'::jsonb then
    raise unique_violation using message = 'Cannot add evidence to a previously acknowledged inspection';
  end if;
  perform private.attach_field_evidence(item.organization_id,item.facility_id,item.id,null,null,p_event_id,p_evidence,item.is_simulated);
  insert into private.field_command_manifests values(auth.uid(),p_event_id,p_evidence);
  return receipt;
end;
$$;
revoke all on function public.submit_inspection_with_evidence from public, anon;
grant execute on function public.submit_inspection_with_evidence to authenticated;

create function public.submit_work_step(p_event_id uuid,p_work_order_id uuid,p_expected_version integer,
  p_target public.work_order_state,p_notes text,p_observed_at timestamptz,p_evidence jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare item public.work_orders; prior public.command_receipts; request jsonb; receipt jsonb; next_version integer;
begin
  select * into item from public.work_orders where id = p_work_order_id for update;
  if not found then raise insufficient_privilege using message = 'Work order unavailable'; end if;
  perform private.require_member(item.organization_id,item.facility_id,array['field','manager','admin']::public.member_role[]);
  if item.assignee_id is distinct from auth.uid() then raise insufficient_privilege using message = 'Assigned worker required'; end if;
  if p_target not in ('in_progress','completed') or p_target is null or p_event_id is null or p_observed_at is null
    or p_expected_version is null or length(coalesce(p_notes,'')) > 4000 then
    raise invalid_parameter_value using message = 'Invalid field step';
  end if;
  request := jsonb_build_object('work_order_id',item.id,'expected_version',p_expected_version,'target',p_target,
    'notes',coalesce(p_notes,''),'observed_at',p_observed_at,'evidence',p_evidence);
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || p_event_id::text,0));
  select * into prior from public.command_receipts where actor_id = auth.uid() and client_event_id = p_event_id;
  if found then
    if prior.request is distinct from request then raise unique_violation using message = 'Idempotency key reused for different content'; end if;
    return prior.receipt;
  end if;
  perform private.attach_field_evidence(item.organization_id,item.facility_id,null,item.id,p_target,p_event_id,p_evidence,item.is_simulated);
  next_version := public.transition_work_order(item.id,p_target,p_expected_version,
    jsonb_build_object('completion_evidence',coalesce(nullif(btrim(p_notes),''),
      (select string_agg(value->>'path',', ') from jsonb_array_elements(p_evidence)))),
    coalesce(nullif(btrim(p_notes),''),'Field step with photo evidence'));
  receipt := jsonb_build_object('client_event_id',p_event_id,'work_order_id',item.id,'version',next_version,
    'received_at',private.record_time(item.organization_id));
  insert into public.command_receipts(client_event_id,actor_id,organization_id,facility_id,request,receipt,is_simulated)
    values(p_event_id,auth.uid(),item.organization_id,item.facility_id,request,receipt,item.is_simulated);
  return receipt;
end;
$$;
revoke all on function public.submit_work_step from public, anon;
grant execute on function public.submit_work_step to authenticated;
