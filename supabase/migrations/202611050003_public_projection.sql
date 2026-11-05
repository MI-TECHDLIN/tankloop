-- Anonymous access is a single narrow lookup by opaque token. No raw table,
-- attachment, staff identity, exact coordinate or reporter note is exposed.
create function public.lookup_public_record(p_token text) returns jsonb
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
  select r.* into confirmed from public.incidents i join public.test_results r on r.id = i.source_id
    where i.organization_id = qr.organization_id and i.facility_id = qr.facility_id and point.id = any(i.point_ids)
      and i.state <> 'resolved' and i.source = 'laboratory' and r.state in ('reviewed','published') and r.value > 0
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
revoke all on function public.lookup_public_record from public;
grant execute on function public.lookup_public_record to anon, authenticated;

-- Reject array references crossing facilities/systems; SQL FKs cannot enforce
-- each item of the affected point array on their own.
create function private.validate_incident_points() returns trigger language plpgsql set search_path = '' as $$
begin
  if exists (select 1 from unnest(new.point_ids) point where not exists (
    select 1 from public.sampling_points p join public.assets a on a.id = p.asset_id
    where p.id = point and p.organization_id = new.organization_id and p.facility_id = new.facility_id and a.system_id = new.system_id
  )) then raise check_violation using message = 'Affected point is outside the incident system'; end if;
  return new;
end;
$$;
create trigger validate_incident_points before insert or update on public.incidents for each row execute function private.validate_incident_points();

create function private.validate_facility_label() returns trigger language plpgsql set search_path = '' as $$
begin
  if new.is_simulated is distinct from (select is_simulated from public.organizations where id = new.organization_id) then raise check_violation using message = 'Simulation label must match the organization'; end if;
  return new;
end;
$$;
create trigger validate_facility_label before insert or update on public.facilities for each row execute function private.validate_facility_label();
revoke all on function private.validate_incident_points, private.validate_facility_label from public, anon, authenticated;
