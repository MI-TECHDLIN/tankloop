-- Resident submissions are private input, never verified laboratory evidence.
create table public.public_concerns (
  id uuid primary key default gen_random_uuid(),
  client_event_id uuid not null unique,
  organization_id uuid not null,
  facility_id uuid not null,
  point_id uuid not null,
  public_record_id uuid not null references public.public_records(id),
  category text not null check (category in ('appearance', 'smell', 'damage', 'mismatch', 'other')),
  description text not null check (length(btrim(description)) >= 5 and length(description) <= 2000),
  reporter_contact text check (length(btrim(reporter_contact)) >= 3 and length(reporter_contact) <= 320),
  contact_consent boolean not null default false,
  received_at timestamptz not null,
  submitted_at timestamptz not null default clock_timestamp(),
  is_simulated boolean not null,
  foreign key (organization_id, facility_id, point_id) references public.sampling_points(organization_id, facility_id, id),
  check (contact_consent = (reporter_contact is not null))
);
create index public_concerns_point_time on public.public_concerns(point_id, submitted_at);
create index public_concerns_scope on public.public_concerns(organization_id, facility_id);
alter table public.public_concerns enable row level security;
revoke all on public.public_concerns from public, anon, authenticated;
grant select on public.public_concerns to authenticated;
create policy manager_read on public.public_concerns for select to authenticated
  using (private.has_membership(organization_id, facility_id, array['manager','admin']::public.member_role[]));
create trigger check_simulation_scope before insert or update on public.public_concerns
  for each row execute function private.validate_scope();

-- The old lookup keeps its null-for-unavailable contract for existing clients.
-- Tighten provenance joins so a source ID alone can never cross point or tenant.
create or replace function public.lookup_public_record(p_token text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  qr public.public_records;
  point public.sampling_points;
  facility public.facilities;
  at_time timestamptz;
  tests jsonb;
  concerns jsonb;
  latest jsonb;
  confirmed public.test_results;
  observed_at timestamptz;
  underway boolean;
  current_data boolean;
  state text;
  wording text;
  indicator_label text;
  finding text;
  action_wording text;
begin
  if p_token is null or p_token !~ '^[a-f0-9]{32,128}$' then return null; end if;
  select * into qr from public.public_records where token = p_token and revoked_at is null;
  if not found then return null; end if;
  select * into point from public.sampling_points where id = qr.point_id;
  select * into facility from public.facilities where id = qr.facility_id;
  at_time := private.record_time(qr.organization_id);
  select coalesce(jsonb_agg(record order by collected_at desc, reviewed_at desc),'[]'::jsonb) into tests from (
    select s.collected_at,r.reviewed_at,jsonb_build_object(
      'indicator',r.indicator,'method',r.method,'value',r.value,'units',r.units,'detection_limit',r.detection_limit,
      'collected_at',s.collected_at,'tested_at',r.tested_at,'reviewed_at',r.reviewed_at,'published_at',r.published_at,'is_simulated',r.is_simulated) record
    from public.test_results r join public.samples s on s.id = r.sample_id
    where s.point_id = point.id and r.organization_id = qr.organization_id and r.facility_id = qr.facility_id
      and r.state = 'published' and r.source = 'laboratory' and r.reviewed_by is not null and r.report_ref is not null
      and r.published_at <= at_time and s.collected_at <= at_time
    order by s.collected_at desc,r.reviewed_at desc limit 20
  ) history;
  latest := tests->0;
  current_data := coalesce((latest->>'collected_at')::timestamptz >= at_time - interval '30 days',false);
  select coalesce(jsonb_agg(jsonb_build_object('source',i.source,'state',i.state,'reported_at',i.reported_at,'is_simulated',i.is_simulated) order by i.reported_at desc),'[]'::jsonb) into concerns
    from public.incidents i where i.organization_id = qr.organization_id and i.facility_id = qr.facility_id and point.id = any(i.point_ids) and i.state <> 'resolved';
  select r.* into confirmed from public.incidents i
    join public.test_results r on r.id = i.source_id and r.organization_id = i.organization_id and r.facility_id = i.facility_id
    join public.samples s on s.id = r.sample_id and s.point_id = point.id
    where i.organization_id = qr.organization_id and i.facility_id = qr.facility_id and point.id = any(i.point_ids)
      and i.state <> 'resolved' and i.source = 'laboratory' and r.source = 'laboratory'
      and r.state in ('reviewed','published') and r.value > 0 and r.reviewed_at <= at_time
      and r.reviewed_by is not null and nullif(btrim(r.report_ref),'') is not null
    order by r.reviewed_at desc limit 1;
  select exists (select 1 from public.work_orders w join public.incidents i on i.id = w.incident_id
    where i.organization_id = qr.organization_id and i.facility_id = qr.facility_id and point.id = any(i.point_ids) and i.state <> 'resolved'
      and w.approved_by is not null and w.state in ('assigned','in_progress','completed','accepted','rework')) into underway;
  select max(i.reported_at) into observed_at from public.incidents i
    where i.organization_id = qr.organization_id and i.facility_id = qr.facility_id and point.id = any(i.point_ids)
      and i.source = 'inspection' and i.state in ('reported','triaged');
  if confirmed.id is not null then
    indicator_label := case confirmed.indicator when 'e_coli' then 'E. coli' when 'total_coliforms' then 'Total coliforms' else 'H₂S screening indicator' end;
    state := 'confirmed_finding';
    wording := 'A verified ' || indicator_label || ' finding was recorded on ' || to_char(confirmed.reviewed_at at time zone 'UTC','YYYY-MM-DD') || '.';
    if underway then action_wording := 'Work is underway. Verification has not yet been completed.'; end if;
  elsif underway then
    state := 'corrective_action_underway'; wording := 'Work is underway. Verification has not yet been completed.';
  elsif observed_at is not null then
    state := 'risk_observed'; wording := 'Inspection concern reported on ' || to_char(observed_at at time zone 'UTC','YYYY-MM-DD') || '. Testing may be needed.';
  elsif jsonb_array_length(concerns) > 0 then
    state := 'under_investigation'; wording := 'A water-quality concern is being investigated.';
  elsif current_data then
    indicator_label := case latest->>'indicator' when 'e_coli' then 'E. coli' when 'total_coliforms' then 'Total coliforms' else 'H₂S screening indicator' end;
    if latest->>'indicator' = 'hydrogen_sulfide' then
      finding := 'H₂S screening indicator ' || case when (latest->>'value')::numeric > 0 then 'detected' else 'not detected' end || ' in this sample on ' || to_char((latest->>'collected_at')::timestamptz at time zone 'UTC','YYYY-MM-DD') || '. This does not establish E. coli presence or absence.';
    elsif (latest->>'value')::numeric = 0 then
      finding := 'No ' || indicator_label || ' detected in this sample on ' || to_char((latest->>'collected_at')::timestamptz at time zone 'UTC','YYYY-MM-DD') || '; other hazards were not assessed.';
    else
      finding := indicator_label || ' detected in this sample on ' || to_char((latest->>'collected_at')::timestamptz at time zone 'UTC','YYYY-MM-DD') || '; other hazards were not assessed.';
    end if;
    state := 'follow_up_reviewed'; wording := 'Follow-up sample reviewed on ' || to_char((latest->>'reviewed_at')::timestamptz at time zone 'UTC','YYYY-MM-DD') || '; ' || finding;
  else
    state := 'no_valid_current_data'; wording := 'We do not have a current verified test record for this point.';
  end if;
  return jsonb_build_object('token',qr.token,'point_label',point.label,'facility_label',facility.public_label,'timezone',facility.timezone,
    'state',state,'wording',wording,'action_wording',action_wording,'updated_at',at_time,'is_simulated',qr.is_simulated,'is_current',current_data,'concerns',concerns,'tests',tests);
end;
$$;

create function public.lookup_public_point(p_token text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare qr public.public_records;
begin
  if p_token is null or p_token !~ '^[a-f0-9]{32,128}$' then
    return jsonb_build_object('status','missing');
  end if;
  select * into qr from public.public_records where token = p_token;
  if not found then return jsonb_build_object('status','missing'); end if;
  if qr.revoked_at is not null then return jsonb_build_object('status','revoked'); end if;
  return jsonb_build_object(
    'status','found', 'record',public.lookup_public_record(p_token),
    'has_unreviewed_results',exists (
      select 1 from public.test_results r join public.samples s on s.id = r.sample_id
      where s.point_id = qr.point_id and r.organization_id = qr.organization_id and r.facility_id = qr.facility_id
        and r.state in ('collected','received','valid','tested')
    )
  );
end;
$$;
revoke all on function public.lookup_public_point from public;
grant execute on function public.lookup_public_point to anon, authenticated;

-- A public caller supplies only the printed token and their own concern.
-- Tenant, point, source, review stage, simulation label and time are server-owned.
create function public.submit_public_concern(
  p_event_id uuid, p_token text, p_category text, p_description text,
  p_contact text default null, p_contact_consent boolean default false
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  qr public.public_records;
  prior public.public_concerns;
  concern public.public_concerns;
  incident_id uuid;
  system_id uuid;
begin
  if p_event_id is null or p_token is null or p_token !~ '^[a-f0-9]{32,128}$'
    or p_category is null or p_category not in ('appearance','smell','damage','mismatch','other')
    or p_description is null or length(btrim(p_description)) < 5 or length(p_description) > 2000
    or p_contact_consent is null or p_contact_consent is distinct from (p_contact is not null)
    or (p_contact is not null and (length(btrim(p_contact)) < 3 or length(p_contact) > 320))
  then raise invalid_parameter_value using message = 'Invalid concern or contact consent'; end if;

  -- Serialize revocation for this label and throttling across labels for one point.
  select * into qr from public.public_records where token = p_token for update;
  if not found or qr.revoked_at is not null then
    raise sqlstate 'PT410' using message = 'This point label is unavailable';
  end if;
  perform 1 from public.sampling_points where id = qr.point_id for update;
  select * into prior from public.public_concerns where client_event_id = p_event_id;
  if found then
    if row(prior.public_record_id,prior.category,prior.description,prior.reporter_contact,prior.contact_consent)
      is distinct from row(qr.id,p_category,p_description,p_contact,p_contact_consent)
    then raise unique_violation using message = 'Receipt key belongs to different content'; end if;
    return jsonb_build_object('event_id',p_event_id,'received_at',prior.received_at,'is_simulated',prior.is_simulated);
  end if;
  if (select count(*) from public.public_concerns
      where point_id = qr.point_id and submitted_at > clock_timestamp() - interval '1 minute') >= 5
  then raise sqlstate 'PT429' using message = 'Please wait before sending another concern'; end if;

  select a.system_id into system_id from public.sampling_points p
    join public.assets a on a.id = p.asset_id where p.id = qr.point_id;
  insert into public.public_concerns(client_event_id,organization_id,facility_id,point_id,public_record_id,
    category,description,reporter_contact,contact_consent,received_at,is_simulated)
  values(p_event_id,qr.organization_id,qr.facility_id,qr.point_id,qr.id,p_category,p_description,p_contact,
    p_contact_consent,private.record_time(qr.organization_id),qr.is_simulated) returning * into concern;
  insert into public.incidents(organization_id,facility_id,system_id,point_ids,source,source_id,reported_at,is_simulated)
  values(qr.organization_id,qr.facility_id,system_id,array[qr.point_id],'resident_report',concern.id,concern.received_at,qr.is_simulated)
  returning id into incident_id;
  perform private.audit(qr.organization_id,qr.facility_id,incident_id::text,'none','reported',
    'Resident concern received for review; no test result is implied.',qr.is_simulated);
  return jsonb_build_object('event_id',p_event_id,'received_at',concern.received_at,'is_simulated',concern.is_simulated);
end;
$$;
revoke all on function public.submit_public_concern from public;
grant execute on function public.submit_public_concern to anon, authenticated;
