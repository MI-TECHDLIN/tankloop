-- Tenant boundaries, immutable provenance, and the three independent lifecycles.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create type public.member_role as enum ('field', 'manager', 'lab', 'admin');
create type public.result_state as enum ('collected', 'received', 'valid', 'rejected', 'tested', 'reviewed', 'published', 'superseded');
create type public.work_order_state as enum ('proposed', 'approval_pending', 'assigned', 'in_progress', 'completed', 'accepted', 'rework');
create type public.incident_state as enum ('reported', 'triaged', 'assigned', 'mitigation', 'verification_pending', 'resolved', 'reopened');
create type public.evidence_source as enum ('resident_report', 'inspection', 'field_screen', 'laboratory');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) > 0),
  jurisdiction text not null default 'NG',
  settings jsonb not null default '{}'::jsonb,
  is_simulated boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.facilities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  public_label text not null,
  timezone text not null default 'Africa/Lagos',
  is_simulated boolean not null default false,
  created_at timestamptz not null default now(),
  unique (organization_id, id)
);
create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  organization_id uuid not null references public.organizations(id),
  facility_id uuid,
  role public.member_role not null,
  status text not null default 'active' check (status in ('active', 'revoked')),
  valid_until timestamptz,
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id) references public.facilities(organization_id, id),
  check (facility_id is not null or role = 'admin'),
  unique nulls not distinct (user_id, organization_id, facility_id, role)
);
create index memberships_lookup on public.memberships(user_id, organization_id, facility_id) where status = 'active';

create table public.water_systems (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  label text not null,
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id) references public.facilities(organization_id, id),
  unique (organization_id, facility_id, id)
);
create table public.assets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  system_id uuid not null,
  parent_asset_id uuid,
  type text not null check (type in ('borehole', 'pump', 'tank', 'line', 'tap')),
  label text not null,
  capacity_litres integer check (capacity_litres > 0),
  retired_at timestamptz,
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id, system_id) references public.water_systems(organization_id, facility_id, id),
  unique (organization_id, facility_id, id),
  unique (organization_id, facility_id, system_id, id),
  foreign key (organization_id, facility_id, system_id, parent_asset_id) references public.assets(organization_id, facility_id, system_id, id),
  check (parent_asset_id is distinct from id)
);
create table public.sampling_points (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  asset_id uuid not null,
  label text not null,
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id, asset_id) references public.assets(organization_id, facility_id, id),
  unique (organization_id, facility_id, id)
);
create table public.checklist_templates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  version integer not null check (version > 0),
  title text not null,
  source text not null,
  asset_type text not null check (asset_type in ('borehole', 'pump', 'tank', 'line', 'tap')),
  questions jsonb not null check (jsonb_typeof(questions) = 'array' and jsonb_array_length(questions) > 0),
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id) references public.facilities(organization_id, id),
  unique (organization_id, facility_id, id),
  unique (organization_id, facility_id, title, version)
);
create table public.inspections (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  asset_id uuid not null,
  template_id uuid not null,
  assigned_to uuid references auth.users(id),
  submitted_by uuid references auth.users(id),
  due_at timestamptz not null,
  observed_at timestamptz,
  received_at timestamptz,
  state text not null default 'scheduled' check (state in ('scheduled', 'submitted')),
  answers jsonb not null default '{}'::jsonb check (jsonb_typeof(answers) = 'object'),
  notes text not null default '' check (length(notes) <= 4000),
  version integer not null default 0 check (version >= 0),
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id, asset_id) references public.assets(organization_id, facility_id, id),
  foreign key (organization_id, facility_id, template_id) references public.checklist_templates(organization_id, facility_id, id),
  unique (organization_id, facility_id, id),
  check (state <> 'submitted' or (received_at is not null and observed_at is not null and submitted_by is not null))
);
create table public.samples (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  organization_id uuid not null,
  facility_id uuid not null,
  point_id uuid not null,
  collector_id uuid not null references auth.users(id),
  collected_at timestamptz not null,
  intended_method text not null,
  preservation_note text not null,
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id, point_id) references public.sampling_points(organization_id, facility_id, id),
  unique (organization_id, facility_id, id)
);
create table public.custody_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  sample_id uuid not null,
  from_actor uuid not null references auth.users(id),
  to_actor uuid not null references auth.users(id),
  occurred_at timestamptz not null,
  note text not null,
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id, sample_id) references public.samples(organization_id, facility_id, id)
);
create table public.test_results (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  sample_id uuid not null,
  source public.evidence_source not null default 'laboratory',
  state public.result_state not null default 'collected',
  indicator text check (indicator in ('e_coli', 'total_coliforms', 'hydrogen_sulfide')),
  method text,
  value numeric check (value >= 0 and value < 1000000000),
  units text check (units in ('cfu_per100ml', 'mpn_per100ml', 'presence_absence')),
  detection_limit numeric check (detection_limit > 0 and detection_limit < 1000000000),
  received_at timestamptz,
  tested_at timestamptz,
  reviewed_at timestamptz,
  published_at timestamptz,
  reviewed_by uuid references auth.users(id),
  report_ref text,
  rejection_reason text,
  revision_of uuid,
  correction_reason text,
  corrected_by uuid references auth.users(id),
  corrected_at timestamptz,
  version integer not null default 0 check (version >= 0),
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id, sample_id) references public.samples(organization_id, facility_id, id),
  unique (organization_id, facility_id, id),
  foreign key (organization_id, facility_id, revision_of) references public.test_results(organization_id, facility_id, id),
  check (state <> 'rejected' or (rejection_reason is not null and length(btrim(rejection_reason)) > 0)),
  check (state not in ('tested', 'reviewed', 'published', 'superseded') or (indicator is not null and method is not null and value is not null and units is not null and detection_limit is not null and tested_at is not null)),
  check (state not in ('reviewed', 'published', 'superseded') or (source = 'laboratory' and reviewed_by is not null and reviewed_at is not null and report_ref is not null and length(btrim(report_ref)) > 0)),
  check (state <> 'published' or published_at is not null),
  check (revision_of is null or (correction_reason is not null and length(btrim(correction_reason)) > 0 and corrected_by is not null and corrected_at is not null)),
  check (units <> 'presence_absence' or value in (0, 1)),
  check (indicator <> 'hydrogen_sulfide' or units = 'presence_absence'),
  check (tested_at is null or tested_at >= received_at),
  check (reviewed_at is null or reviewed_at >= tested_at),
  check (published_at is null or published_at >= reviewed_at)
);
create unique index one_active_result_revision on public.test_results(sample_id) where state <> 'superseded';

create table public.incidents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  system_id uuid not null,
  point_ids uuid[] not null check (cardinality(point_ids) > 0),
  source public.evidence_source not null,
  source_id uuid not null,
  state public.incident_state not null default 'reported',
  reported_at timestamptz not null default now(),
  priority text check (priority in ('routine', 'urgent', 'critical')),
  uncertainty text,
  owner_id uuid references auth.users(id),
  due_at timestamptz,
  required_response text,
  action_evidence text,
  resolved_at timestamptz,
  communication_ref text,
  escalated_at timestamptz,
  version integer not null default 0 check (version >= 0),
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id, system_id) references public.water_systems(organization_id, facility_id, id),
  unique (organization_id, facility_id, id),
  unique (organization_id, source, source_id)
);
create table public.work_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  incident_id uuid not null,
  task text not null check (length(btrim(task)) > 0),
  state public.work_order_state not null default 'proposed',
  approved_by uuid references auth.users(id),
  assignee_id uuid references auth.users(id),
  due_at timestamptz,
  completion_evidence text,
  version integer not null default 0 check (version >= 0),
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id, incident_id) references public.incidents(organization_id, facility_id, id),
  unique (organization_id, facility_id, id)
);
create table public.verification_requirements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  incident_id uuid not null,
  kind text not null check (kind in ('sample', 'checklist')),
  point_id uuid,
  template_id uuid,
  indicator text,
  method text,
  not_before timestamptz not null,
  fresh_for interval not null default '30 days' check (fresh_for > interval '0 seconds'),
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id, incident_id) references public.incidents(organization_id, facility_id, id),
  foreign key (organization_id, facility_id, point_id) references public.sampling_points(organization_id, facility_id, id),
  foreign key (organization_id, facility_id, template_id) references public.checklist_templates(organization_id, facility_id, id),
  check ((kind = 'sample' and point_id is not null and template_id is null and indicator is not null and method is not null) or (kind = 'checklist' and template_id is not null and point_id is null))
);
create table public.public_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  point_id uuid not null,
  token text not null unique default replace(gen_random_uuid()::text, '-', '') check (length(token) between 32 and 128),
  issued_at timestamptz not null default now(),
  revoked_at timestamptz,
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id, point_id) references public.sampling_points(organization_id, facility_id, id)
);
create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  aggregate_id text not null,
  actor_id uuid references auth.users(id),
  occurred_at timestamptz not null default now(),
  previous_state text not null,
  new_state text not null,
  reason text not null,
  evidence_ids jsonb not null default '[]'::jsonb,
  device_id text not null default 'server',
  is_simulated boolean not null default false,
  foreign key (organization_id, facility_id) references public.facilities(organization_id, id)
);
create table public.command_receipts (
  client_event_id uuid not null,
  actor_id uuid not null references auth.users(id),
  organization_id uuid not null,
  facility_id uuid not null,
  request jsonb not null,
  receipt jsonb not null,
  is_simulated boolean not null default false,
  primary key (actor_id, client_event_id),
  foreign key (organization_id, facility_id) references public.facilities(organization_id, id)
);

create function private.has_membership(p_org uuid, p_facility uuid, p_roles public.member_role[] default array['field','manager','lab','admin']::public.member_role[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid() and m.organization_id = p_org
      and (p_facility is null or m.facility_id = p_facility or (m.facility_id is null and m.role = 'admin'))
      and m.role = any(p_roles) and m.status = 'active' and (m.valid_until is null or m.valid_until > now())
  );
$$;
revoke all on function private.has_membership from public, anon;
grant execute on function private.has_membership to authenticated;

create function private.require_member(p_org uuid, p_facility uuid, p_roles public.member_role[])
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.has_membership(p_org, p_facility, p_roles) then
    raise insufficient_privilege using message = 'Active scoped membership required';
  end if;
end;
$$;
revoke all on function private.require_member from public, anon, authenticated;

-- Simulated clocks are provisioned only by trusted seed tooling. Production
-- receipts always use the server clock. Membership expiry always uses real time.
create function private.record_time(p_org uuid) returns timestamptz
language sql stable security definer set search_path = '' as $$
  select case when is_simulated and settings ? 'simulation_clock'
    then (settings->>'simulation_clock')::timestamptz else statement_timestamp() end
  from public.organizations where id = p_org;
$$;
revoke all on function private.record_time from public, anon, authenticated;

create function private.audit(p_org uuid, p_facility uuid, p_id text, p_from text, p_to text, p_reason text, p_simulated boolean, p_evidence jsonb default '[]'::jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_reason is null or length(btrim(p_reason)) = 0 then raise invalid_parameter_value using message = 'Reason required'; end if;
  insert into public.audit_events (organization_id, facility_id, aggregate_id, actor_id, occurred_at, previous_state, new_state, reason, is_simulated, evidence_ids)
  values (p_org, p_facility, p_id, auth.uid(), private.record_time(p_org), p_from, p_to, p_reason, p_simulated, p_evidence);
end;
$$;
revoke all on function private.audit from public, anon, authenticated;

create function private.immutable_record() returns trigger language plpgsql set search_path = '' as $$
begin raise insufficient_privilege using message = 'Append-only record: retain the original and create a revision'; end;
$$;
create trigger immutable_audit before update or delete on public.audit_events for each row execute function private.immutable_record();
create trigger immutable_custody before update or delete on public.custody_events for each row execute function private.immutable_record();
create trigger immutable_templates before update or delete on public.checklist_templates for each row execute function private.immutable_record();
create trigger immutable_samples before update or delete on public.samples for each row execute function private.immutable_record();

create function private.protect_result() returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise insufficient_privilege using message = 'Results cannot be deleted'; end if;
  if old.state in ('reviewed','published','superseded') and
    (to_jsonb(old) - array['state','version','published_at']) is distinct from (to_jsonb(new) - array['state','version','published_at']) then
    raise insufficient_privilege using message = 'Reviewed evidence requires a superseding revision';
  end if;
  if old.state = 'superseded' then raise insufficient_privilege using message = 'Superseded evidence is immutable'; end if;
  return new;
end;
$$;
create trigger protect_result before update or delete on public.test_results for each row execute function private.protect_result();

create function private.protect_qr() returns trigger language plpgsql set search_path = '' as $$
begin
  if row(new.token,new.point_id,new.organization_id,new.facility_id) is distinct from row(old.token,old.point_id,old.organization_id,old.facility_id)
    or (old.revoked_at is not null and new.revoked_at is distinct from old.revoked_at) then
    raise insufficient_privilege using message = 'QR identity is permanent; revoke and issue a new token';
  end if;
  return new;
end;
$$;
create trigger protect_qr before update on public.public_records for each row execute function private.protect_qr();

create function private.validate_scope() returns trigger language plpgsql set search_path = '' as $$
declare expected boolean;
begin
  select is_simulated into expected from public.facilities where id = new.facility_id and organization_id = new.organization_id;
  if expected is distinct from new.is_simulated then raise check_violation using message = 'Simulation label must match the facility'; end if;
  return new;
end;
$$;

-- SELECT is tenant/facility scoped. No client role has arbitrary table writes.
-- All mutations below are constrained RPC transactions, not UI role switches.
do $$
declare t text;
begin
  foreach t in array array['organizations','facilities','memberships','water_systems','assets','sampling_points','checklist_templates','inspections','samples','custody_events','test_results','incidents','work_orders','verification_requirements','public_records','audit_events','command_receipts'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
    if t not in ('organizations','facilities','memberships') then
      execute format('create policy tenant_read on public.%I for select to authenticated using (private.has_membership(organization_id, facility_id))', t);
      execute format('create trigger check_simulation_scope before insert or update on public.%I for each row execute function private.validate_scope()', t);
      execute format('create index on public.%I (organization_id, facility_id)', t);
    end if;
  end loop;
end;
$$;
create policy tenant_read on public.organizations for select to authenticated using (private.has_membership(id, null));
create policy facility_read on public.facilities for select to authenticated using (private.has_membership(organization_id, id));
create policy own_memberships on public.memberships for select to authenticated using (user_id = auth.uid());
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.has_membership to authenticated;
