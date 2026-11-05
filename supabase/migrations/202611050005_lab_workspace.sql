-- Lab reads and commands extend the existing result lifecycle. A client never
-- writes a reviewer, review timestamp, correction lineage or receipt itself.
create function private.guard_lab_review() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.state in ('reviewed', 'published', 'superseded') then
    if new.report_ref !~ '^https://[^[:space:]@/?#]+([/?#][^[:space:]]*)?$'
      and not (new.is_simulated and new.report_ref ~ '^simulation://[^[:space:]]+$') then
      raise invalid_parameter_value using message = 'Link the signed report using HTTPS; simulation references are only for simulated records';
    end if;
    if new.state = 'reviewed' and auth.uid() is not null then
      perform private.require_member(new.organization_id, new.facility_id, array['lab']::public.member_role[]);
      if new.reviewed_by is distinct from auth.uid() then
        raise insufficient_privilege using message = 'The authenticated laboratory reviewer must attest their own review';
      end if;
    end if;
  end if;
  if tg_op = 'UPDATE' and old.state = 'rejected' then
    raise insufficient_privilege using message = 'A rejected sample cannot become verification evidence';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_lab_review from public, anon, authenticated;
create trigger guard_lab_review before insert or update on public.test_results
  for each row execute function private.guard_lab_review();

-- Keep the existing correction API compatible while allowing a corrected
-- detection limit. The method, analyte, units and sample remain in scope.
create function private.correct_lab_result(
  p_id uuid, p_expected_version integer, p_value numeric,
  p_detection_limit numeric, p_report_ref text, p_reason text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare r public.test_results; new_id uuid; at_time timestamptz;
begin
  select * into r from public.test_results where id = p_id for update;
  if not found then raise insufficient_privilege using message = 'Result unavailable'; end if;
  perform private.require_member(r.organization_id, r.facility_id, array['lab']::public.member_role[]);
  if r.version is distinct from p_expected_version then
    raise serialization_failure using message = 'Result version conflict';
  end if;
  if r.state not in ('reviewed', 'published') or p_value is null
    or p_detection_limit is null or coalesce(length(btrim(p_report_ref)), 0) = 0
    or coalesce(length(btrim(p_reason)), 0) = 0 then
    raise invalid_parameter_value using message = 'Reviewed original, corrected measurement, signed report and reason required';
  end if;
  at_time := private.record_time(r.organization_id);
  if at_time < greatest(r.reviewed_at, r.published_at) then
    raise invalid_parameter_value using message = 'Correction cannot predate original';
  end if;
  update public.test_results set state = 'superseded', version = version + 1 where id = r.id;
  insert into public.test_results(
    organization_id, facility_id, sample_id, source, state, indicator, method,
    value, units, detection_limit, received_at, tested_at, reviewed_at,
    reviewed_by, report_ref, revision_of, correction_reason, corrected_by,
    corrected_at, is_simulated
  ) values (
    r.organization_id, r.facility_id, r.sample_id, r.source, 'reviewed', r.indicator, r.method,
    p_value, r.units, p_detection_limit, r.received_at, r.tested_at, at_time,
    auth.uid(), p_report_ref, r.id, p_reason, auth.uid(), at_time, r.is_simulated
  ) returning id into new_id;
  perform private.audit(r.organization_id, r.facility_id, r.id::text, r.state::text,
    'superseded', p_reason, r.is_simulated, jsonb_build_array(new_id, p_report_ref));
  perform private.audit(r.organization_id, r.facility_id, new_id::text, 'none',
    'reviewed', p_reason, r.is_simulated, jsonb_build_array(r.id, p_report_ref));
  perform private.open_lab_incident(new_id);
  return new_id;
end;
$$;
revoke all on function private.correct_lab_result from public, anon, authenticated;

create or replace function public.correct_result(
  p_id uuid, p_expected_version integer, p_value numeric, p_report_ref text, p_reason text
) returns uuid language sql security definer set search_path = '' as $$
  select private.correct_lab_result(p_id, p_expected_version, p_value,
    (select detection_limit from public.test_results where id = p_id), p_report_ref, p_reason);
$$;

-- A consistent, facility-scoped snapshot. Existing table RLS remains in force
-- for ordinary reads; this restricted projection additionally requires lab access.
create function public.lab_workspace(p_facility_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare f public.facilities; records jsonb; facilities jsonb;
begin
  select * into f from public.facilities
  where (p_facility_id is null or id = p_facility_id)
    and private.has_membership(organization_id, id, array['lab']::public.member_role[])
  order by id limit 1;
  if not found then raise insufficient_privilege using message = 'An active, scoped laboratory reviewer membership is required'; end if;
  select jsonb_agg(to_jsonb(allowed) order by allowed.public_label, allowed.id) into facilities
    from public.facilities allowed
    where private.has_membership(allowed.organization_id, allowed.id, array['lab']::public.member_role[]);
  select coalesce(jsonb_agg(
    to_jsonb(r) || jsonb_build_object(
      'sample', to_jsonb(s), 'point_label', p.label,
      'custody', (select coalesce(jsonb_agg(to_jsonb(c) order by c.occurred_at, c.id), '[]'::jsonb)
        from public.custody_events c where c.sample_id = s.id),
      'audit', (select coalesce(jsonb_agg(to_jsonb(a) order by a.occurred_at, a.id), '[]'::jsonb)
        from public.audit_events a where a.organization_id = f.organization_id
          and a.facility_id = f.id and a.aggregate_id = r.id::text),
      'open_incident_count', (select count(*) from public.incidents i
        where i.organization_id = f.organization_id and i.facility_id = f.id
          and p.id = any(i.point_ids) and i.state <> 'resolved')
    ) order by s.collected_at desc, r.reviewed_at desc nulls last, r.id
  ), '[]'::jsonb) into records
  from public.test_results r join public.samples s on s.id = r.sample_id
    join public.sampling_points p on p.id = s.point_id
  where r.organization_id = f.organization_id and r.facility_id = f.id;
  return jsonb_build_object(
    'facility', to_jsonb(f), 'facilities', facilities, 'actor_id', auth.uid(),
    'as_of', private.record_time(f.organization_id), 'fetched_at', statement_timestamp(),
    'simulation', (select settings from public.organizations where id = f.organization_id),
    'records', records
  );
end;
$$;
revoke all on function public.lab_workspace from public, anon;
grant execute on function public.lab_workspace to authenticated;

-- One idempotent transaction per user action. Intake receipt and validity are
-- atomic, and a lost acknowledgement can be retried without a second revision.
create function public.lab_command(
  p_event_id uuid, p_result_id uuid, p_expected_version integer,
  p_action text, p_payload jsonb, p_reason text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r public.test_results; prior public.command_receipts; request jsonb;
  receipt jsonb; result_id uuid; next_version integer;
begin
  if p_event_id is null or p_expected_version is null or p_expected_version < 0
    or jsonb_typeof(p_payload) is distinct from 'object'
    or coalesce(length(btrim(p_reason)), 0) = 0 or length(p_reason) > 4000 then
    raise invalid_parameter_value using message = 'Event, version, payload and reason required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || p_event_id::text, 0));
  select * into r from public.test_results where id = p_result_id for update;
  if not found then raise insufficient_privilege using message = 'Result unavailable'; end if;
  perform private.require_member(r.organization_id, r.facility_id, array['lab']::public.member_role[]);
  request := jsonb_build_object('result_id', p_result_id, 'expected_version', p_expected_version,
    'action', p_action, 'payload', p_payload, 'reason', p_reason);
  select * into prior from public.command_receipts
    where actor_id = auth.uid() and client_event_id = p_event_id;
  if found then
    if prior.request <> request then raise unique_violation using message = 'Idempotency key reused for different content'; end if;
    return prior.receipt;
  end if;
  if r.version <> p_expected_version then raise serialization_failure using message = 'Result version conflict'; end if;
  result_id := r.id;
  case p_action
    when 'accept', 'reject' then
      if r.state not in ('collected', 'received') then
        raise invalid_parameter_value using message = 'Only a pending sample can enter intake';
      end if;
      next_version := r.version;
      if r.state = 'collected' then
        if coalesce(length(btrim(p_payload->>'custody_note')), 0) = 0 then
          raise invalid_parameter_value using message = 'Record the custody handoff before intake';
        end if;
        next_version := public.transition_result(r.id, 'received', next_version, p_payload, p_reason);
      end if;
      perform public.transition_result(r.id,
        case when p_action = 'accept' then 'valid'::public.result_state else 'rejected'::public.result_state end,
        next_version, jsonb_build_object('rejection_reason', p_reason), p_reason);
    when 'enter_result' then
      perform public.transition_result(r.id, 'tested', r.version, p_payload, p_reason);
    when 'attest' then
      perform public.transition_result(r.id, 'reviewed', r.version, p_payload, p_reason);
    when 'correct' then
      result_id := private.correct_lab_result(r.id, r.version, (p_payload->>'value')::numeric,
        (p_payload->>'detection_limit')::numeric, p_payload->>'report_ref', p_reason);
    else
      raise invalid_parameter_value using message = 'Unknown lab action';
  end case;
  select * into r from public.test_results where id = result_id;
  receipt := jsonb_build_object('client_event_id', p_event_id, 'result_id', r.id,
    'previous_result_id', p_result_id, 'action', p_action, 'version', r.version,
    'state', r.state, 'actor_id', auth.uid(), 'recorded_at', private.record_time(r.organization_id),
    'is_simulated', r.is_simulated);
  insert into public.command_receipts(client_event_id, actor_id, organization_id,
    facility_id, request, receipt, is_simulated)
  values(p_event_id, auth.uid(), r.organization_id, r.facility_id, request, receipt, r.is_simulated);
  return receipt;
end;
$$;
revoke all on function public.lab_command from public, anon;
grant execute on function public.lab_command to authenticated;
