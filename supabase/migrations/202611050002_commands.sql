-- Public RPCs own authorization, version checks, transactions and audit.
create function public.submit_inspection(p_event_id uuid, p_inspection_id uuid, p_expected_version integer, p_answers jsonb, p_notes text, p_observed_at timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  item public.inspections;
  template public.checklist_templates;
  prior public.command_receipts;
  request jsonb;
  receipt jsonb;
  at_time timestamptz;
  affected uuid[];
  system uuid;
  case_id uuid;
begin
  select * into item from public.inspections where id = p_inspection_id for update;
  if not found then raise insufficient_privilege using message = 'Assignment unavailable'; end if;
  perform private.require_member(item.organization_id,item.facility_id,array['field','manager','admin']::public.member_role[]);
  if item.assigned_to is not null and item.assigned_to <> auth.uid() and not private.has_membership(item.organization_id,item.facility_id,array['manager','admin']::public.member_role[]) then
    raise insufficient_privilege using message = 'Not the assigned inspector';
  end if;
  if p_event_id is null or p_observed_at is null or p_expected_version is null or p_expected_version < 0 or jsonb_typeof(p_answers) is distinct from 'object' then raise invalid_parameter_value using message = 'Invalid inspection command'; end if;
  request := jsonb_build_object('inspection_id',p_inspection_id,'expected_version',p_expected_version,'answers',p_answers,'notes',coalesce(p_notes,''),'observed_at',p_observed_at);
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || p_event_id::text,0));
  select * into prior from public.command_receipts where actor_id = auth.uid() and client_event_id = p_event_id;
  if found then
    if prior.request <> request then raise unique_violation using message = 'Idempotency key reused for different content'; end if;
    return prior.receipt;
  end if;
  if item.version <> p_expected_version or item.state <> 'scheduled' then raise serialization_failure using message = 'Inspection version conflict'; end if;
  select * into template from public.checklist_templates where id = item.template_id;
  if exists (select 1 from jsonb_array_elements(template.questions) q where coalesce((q->>'required')::boolean,true) and not (p_answers ? (q->>'id')))
    or exists (select 1 from jsonb_each(p_answers) a where not exists (select 1 from jsonb_array_elements(template.questions) q where q->>'id' = a.key)
      or coalesce(a.value->>'choice','') not in ('yes','no','unknown','not_applicable') or length(coalesce(a.value->>'note','')) > 1000)
    or length(coalesce(p_notes,'')) > 4000 then raise invalid_parameter_value using message = 'Checklist answers or version invalid'; end if;
  at_time := private.record_time(item.organization_id);
  update public.inspections set answers = p_answers, notes = coalesce(p_notes,''), observed_at = p_observed_at,
    received_at = at_time, submitted_by = auth.uid(), state = 'submitted', version = version + 1 where id = item.id;
  perform private.audit(item.organization_id,item.facility_id,item.id::text,'scheduled','submitted','Inspection submitted',item.is_simulated,jsonb_build_array(p_event_id, item.template_id));
  if exists (select 1 from jsonb_each(p_answers) a where a.value->>'choice' = 'yes') then
    select system_id into system from public.assets where id = item.asset_id;
    select array_agg(id) into affected from public.sampling_points where asset_id = item.asset_id;
    if affected is null then select array_agg(p.id) into affected from public.sampling_points p join public.assets a on a.id = p.asset_id where a.system_id = system; end if;
    if affected is null then raise invalid_parameter_value using message = 'Register the affected system sampling points before submitting a risk'; end if;
    insert into public.incidents(organization_id,facility_id,system_id,point_ids,source,source_id,reported_at,is_simulated)
      values(item.organization_id,item.facility_id,system,affected,'inspection',item.id,at_time,item.is_simulated) returning id into case_id;
    perform private.audit(item.organization_id,item.facility_id,case_id::text,'none','reported','Inspection risk observed; no laboratory result implied',item.is_simulated,jsonb_build_array(item.id));
  end if;
  receipt := jsonb_build_object('client_event_id',p_event_id,'inspection_id',item.id,'version',item.version+1,'received_at',at_time);
  insert into public.command_receipts(client_event_id,actor_id,organization_id,facility_id,request,receipt,is_simulated)
    values(p_event_id,auth.uid(),item.organization_id,item.facility_id,request,receipt,item.is_simulated);
  return receipt;
end;
$$;
revoke all on function public.submit_inspection from public, anon;
grant execute on function public.submit_inspection to authenticated;

create function public.register_sample(p_point_id uuid, p_collected_at timestamptz, p_method text, p_preservation_note text, p_sample_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare point public.sampling_points; result_id uuid; existing public.samples;
begin
  select * into point from public.sampling_points where id = p_point_id;
  if not found then raise insufficient_privilege using message = 'Sampling point unavailable'; end if;
  perform private.require_member(point.organization_id,point.facility_id,array['field']::public.member_role[]);
  if p_sample_id is null or p_collected_at is null or p_collected_at > private.record_time(point.organization_id) + interval '5 minutes' or coalesce(length(btrim(p_method)),0) = 0 or coalesce(length(btrim(p_preservation_note)),0) = 0 then raise invalid_parameter_value using message = 'Method, collection time and preservation details required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_sample_id::text,0));
  select * into existing from public.samples where id = p_sample_id;
  if found then
    if existing.point_id <> p_point_id or existing.collector_id <> auth.uid() or existing.collected_at <> p_collected_at or existing.intended_method <> p_method or existing.preservation_note <> p_preservation_note then raise unique_violation using message = 'Sample identity reused'; end if;
    return (select id from public.test_results where sample_id = p_sample_id and state <> 'superseded');
  end if;
  insert into public.samples(id,code,organization_id,facility_id,point_id,collector_id,collected_at,intended_method,preservation_note,is_simulated)
    values(p_sample_id,'TL-' || p_sample_id::text,point.organization_id,point.facility_id,point.id,auth.uid(),p_collected_at,p_method,p_preservation_note,point.is_simulated);
  insert into public.test_results(organization_id,facility_id,sample_id,is_simulated) values(point.organization_id,point.facility_id,p_sample_id,point.is_simulated) returning id into result_id;
  perform private.audit(point.organization_id,point.facility_id,result_id::text,'none','collected','Sample registered',point.is_simulated,jsonb_build_array(p_sample_id));
  return result_id;
end;
$$;
revoke all on function public.register_sample from public, anon;
grant execute on function public.register_sample to authenticated;

create function private.open_lab_incident(p_result_id uuid) returns void language plpgsql security definer set search_path = '' as $$
declare r public.test_results; s public.samples; system uuid; case_id uuid;
begin
  select * into r from public.test_results where id = p_result_id;
  if r.state not in ('reviewed','published') or r.source <> 'laboratory' or r.indicator <> 'e_coli' or r.value <= 0 then return; end if;
  select * into s from public.samples where id = r.sample_id;
  select a.system_id into system from public.sampling_points p join public.assets a on a.id = p.asset_id where p.id = s.point_id;
  insert into public.incidents(organization_id,facility_id,system_id,point_ids,source,source_id,reported_at,is_simulated)
    values(r.organization_id,r.facility_id,system,array[s.point_id],'laboratory',r.id,private.record_time(r.organization_id),r.is_simulated)
    on conflict (organization_id,source,source_id) do nothing returning id into case_id;
  if case_id is not null then perform private.audit(r.organization_id,r.facility_id,case_id::text,'none','reported','Reviewed E. coli finding',r.is_simulated,jsonb_build_array(r.id)); end if;
end;
$$;
revoke all on function private.open_lab_incident from public, anon, authenticated;

create function public.transition_result(p_id uuid, p_target public.result_state, p_expected_version integer, p_payload jsonb, p_reason text)
returns integer language plpgsql security definer set search_path = '' as $$
declare r public.test_results; s public.samples; at_time timestamptz; allowed boolean;
begin
  select * into r from public.test_results where id = p_id for update;
  if not found then raise insufficient_privilege using message = 'Result unavailable'; end if;
  perform private.require_member(r.organization_id,r.facility_id,case when p_target = 'published' then array['manager','admin']::public.member_role[] else array['lab']::public.member_role[] end);
  if r.version is distinct from p_expected_version then raise serialization_failure using message = 'Result version conflict'; end if;
  allowed := case r.state
    when 'collected' then p_target = 'received' when 'received' then p_target in ('valid','rejected')
    when 'valid' then p_target = 'tested' when 'tested' then p_target = 'reviewed'
    when 'reviewed' then p_target = 'published' else false end;
  if not coalesce(allowed,false) then raise invalid_parameter_value using message = 'Invalid result transition; corrections require a revision'; end if;
  select * into s from public.samples where id = r.sample_id;
  at_time := private.record_time(r.organization_id);
  if at_time < greatest(s.collected_at,r.received_at,r.tested_at,r.reviewed_at,r.published_at) then raise invalid_parameter_value using message = 'Result chronology invalid'; end if;
  if p_target = 'received' then
    insert into public.custody_events(organization_id,facility_id,sample_id,from_actor,to_actor,occurred_at,note,is_simulated)
      values(r.organization_id,r.facility_id,s.id,s.collector_id,auth.uid(),at_time,coalesce(p_payload->>'custody_note','Laboratory receipt recorded'),r.is_simulated);
  end if;
  if p_target = 'rejected' and coalesce(length(btrim(p_payload->>'rejection_reason')),0) = 0 then raise invalid_parameter_value using message = 'Sample rejection reason required'; end if;
  if p_target = 'tested' and (p_payload->>'method' is distinct from s.intended_method or p_payload->>'indicator' is null or p_payload->>'value' is null or p_payload->>'units' is null or p_payload->>'detection_limit' is null) then raise invalid_parameter_value using message = 'Exact method, indicator, value, units and detection limit required'; end if;
  if p_target = 'reviewed' and (r.source <> 'laboratory' or coalesce(length(btrim(p_payload->>'report_ref')),0) = 0) then raise invalid_parameter_value using message = 'Authorized laboratory review and linked report required'; end if;
  update public.test_results set state = p_target, version = version+1,
    received_at = case when p_target = 'received' then at_time else received_at end,
    rejection_reason = case when p_target = 'rejected' then p_payload->>'rejection_reason' else rejection_reason end,
    tested_at = case when p_target = 'tested' then at_time else tested_at end,
    indicator = case when p_target = 'tested' then p_payload->>'indicator' else indicator end,
    method = case when p_target = 'tested' then p_payload->>'method' else method end,
    value = case when p_target = 'tested' then (p_payload->>'value')::numeric else value end,
    units = case when p_target = 'tested' then p_payload->>'units' else units end,
    detection_limit = case when p_target = 'tested' then (p_payload->>'detection_limit')::numeric else detection_limit end,
    reviewed_at = case when p_target = 'reviewed' then at_time else reviewed_at end,
    reviewed_by = case when p_target = 'reviewed' then auth.uid() else reviewed_by end,
    report_ref = case when p_target = 'reviewed' then p_payload->>'report_ref' else report_ref end,
    published_at = case when p_target = 'published' then at_time else published_at end where id = r.id;
  perform private.audit(r.organization_id,r.facility_id,r.id::text,r.state::text,p_target::text,p_reason,r.is_simulated,jsonb_build_array(s.id, p_payload->>'report_ref'));
  if p_target = 'reviewed' then perform private.open_lab_incident(r.id); end if;
  return r.version+1;
end;
$$;
revoke all on function public.transition_result from public, anon;
grant execute on function public.transition_result to authenticated;

create function public.correct_result(p_id uuid, p_expected_version integer, p_value numeric, p_report_ref text, p_reason text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare r public.test_results; new_id uuid; at_time timestamptz;
begin
  select * into r from public.test_results where id = p_id for update;
  if not found then raise insufficient_privilege using message = 'Result unavailable'; end if;
  perform private.require_member(r.organization_id,r.facility_id,array['lab']::public.member_role[]);
  if r.version is distinct from p_expected_version then raise serialization_failure using message = 'Result version conflict'; end if;
  if r.state not in ('reviewed','published') or p_value is null or coalesce(length(btrim(p_report_ref)),0) = 0 or coalesce(length(btrim(p_reason)),0) = 0 then raise invalid_parameter_value using message = 'Reviewed original, corrected value, report and reason required'; end if;
  at_time := private.record_time(r.organization_id);
  if at_time < greatest(r.reviewed_at,r.published_at) then raise invalid_parameter_value using message = 'Correction cannot predate original'; end if;
  update public.test_results set state = 'superseded',version = version+1 where id = r.id;
  insert into public.test_results(organization_id,facility_id,sample_id,source,state,indicator,method,value,units,detection_limit,received_at,tested_at,reviewed_at,reviewed_by,report_ref,revision_of,correction_reason,corrected_by,corrected_at,is_simulated)
    values(r.organization_id,r.facility_id,r.sample_id,r.source,'reviewed',r.indicator,r.method,p_value,r.units,r.detection_limit,r.received_at,r.tested_at,at_time,auth.uid(),p_report_ref,r.id,p_reason,auth.uid(),at_time,r.is_simulated) returning id into new_id;
  perform private.audit(r.organization_id,r.facility_id,r.id::text,r.state::text,'superseded',p_reason,r.is_simulated,jsonb_build_array(new_id,p_report_ref));
  perform private.audit(r.organization_id,r.facility_id,new_id::text,'none','reviewed',p_reason,r.is_simulated,jsonb_build_array(r.id,p_report_ref));
  perform private.open_lab_incident(new_id);
  return new_id;
end;
$$;
revoke all on function public.correct_result from public, anon;
grant execute on function public.correct_result to authenticated;

create function public.propose_work_order(p_id uuid, p_incident_id uuid, p_task text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare incident public.incidents; existing public.work_orders;
begin
  select * into incident from public.incidents where id = p_incident_id;
  if not found then raise insufficient_privilege using message = 'Incident unavailable'; end if;
  perform private.require_member(incident.organization_id,incident.facility_id,array['field','manager','admin']::public.member_role[]);
  if p_id is null or coalesce(length(btrim(p_task)),0) = 0 or incident.state = 'resolved' then raise invalid_parameter_value using message = 'Active incident and task required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
  select * into existing from public.work_orders where id = p_id;
  if found then
    if existing.incident_id <> p_incident_id or existing.task <> p_task then raise unique_violation using message = 'Work order identity reused'; end if;
    return p_id;
  end if;
  insert into public.work_orders(id,organization_id,facility_id,incident_id,task,is_simulated) values(p_id,incident.organization_id,incident.facility_id,incident.id,p_task,incident.is_simulated);
  perform private.audit(incident.organization_id,incident.facility_id,p_id::text,'none','proposed','Work requested',incident.is_simulated,jsonb_build_array(incident.id));
  return p_id;
end;
$$;
revoke all on function public.propose_work_order from public, anon;
grant execute on function public.propose_work_order to authenticated;

create function public.transition_work_order(p_id uuid, p_target public.work_order_state, p_expected_version integer, p_payload jsonb, p_reason text)
returns integer language plpgsql security definer set search_path = '' as $$
declare w public.work_orders; at_time timestamptz; allowed boolean; assignee uuid;
begin
  select * into w from public.work_orders where id = p_id for update;
  if not found then raise insufficient_privilege using message = 'Work order unavailable'; end if;
  perform private.require_member(w.organization_id,w.facility_id,case when p_target in ('assigned','accepted','rework') then array['manager','admin']::public.member_role[] else array['field','manager','admin']::public.member_role[] end);
  if w.version is distinct from p_expected_version then raise serialization_failure using message = 'Work order version conflict'; end if;
  allowed := case w.state when 'proposed' then p_target = 'approval_pending' when 'approval_pending' then p_target = 'assigned'
    when 'assigned' then p_target = 'in_progress' when 'in_progress' then p_target = 'completed'
    when 'completed' then p_target in ('accepted','rework') when 'rework' then p_target = 'in_progress' else false end;
  if not coalesce(allowed,false) then raise invalid_parameter_value using message = 'Invalid work-order transition'; end if;
  at_time := private.record_time(w.organization_id);
  if p_target = 'assigned' then
    assignee := (p_payload->>'assignee_id')::uuid;
    if assignee is null or p_payload->>'due_at' is null or (p_payload->>'due_at')::timestamptz <= at_time or not exists (select 1 from public.memberships m where m.user_id = assignee and m.organization_id = w.organization_id and m.facility_id = w.facility_id and m.role = 'field' and m.status = 'active' and (m.valid_until is null or m.valid_until > now())) then raise invalid_parameter_value using message = 'Active assignee and future deadline required'; end if;
  end if;
  if p_target in ('in_progress','completed') and w.assignee_id is distinct from auth.uid() then raise insufficient_privilege using message = 'Assigned worker required'; end if;
  if p_target = 'completed' and coalesce(length(btrim(p_payload->>'completion_evidence')),0) = 0 then raise invalid_parameter_value using message = 'Completion evidence required'; end if;
  update public.work_orders set state = p_target, version = version+1,
    assignee_id = case when p_target = 'assigned' then assignee else assignee_id end,
    approved_by = case when p_target = 'assigned' then auth.uid() else approved_by end,
    due_at = case when p_target = 'assigned' then (p_payload->>'due_at')::timestamptz else due_at end,
    completion_evidence = case when p_target = 'completed' then p_payload->>'completion_evidence' when p_target = 'in_progress' and w.state = 'rework' then null else completion_evidence end where id = w.id;
  perform private.audit(w.organization_id,w.facility_id,w.id::text,w.state::text,p_target::text,p_reason,w.is_simulated,jsonb_build_array(w.incident_id,p_payload->>'completion_evidence'));
  -- Deliberately no UPDATE of incidents here. Repair completion is not closure.
  return w.version+1;
end;
$$;
revoke all on function public.transition_work_order from public, anon;
grant execute on function public.transition_work_order to authenticated;

create function public.set_verification_plan(p_incident_id uuid, p_expected_version integer, p_requirements jsonb, p_reason text)
returns integer language plpgsql security definer set search_path = '' as $$
declare i public.incidents; q jsonb; original jsonb; required_indicator text; required_method text;
begin
  select * into i from public.incidents where id = p_incident_id for update;
  if not found then raise insufficient_privilege using message = 'Incident unavailable'; end if;
  perform private.require_member(i.organization_id,i.facility_id,array['manager','admin']::public.member_role[]);
  if i.version is distinct from p_expected_version then raise serialization_failure using message = 'Incident version conflict'; end if;
  if i.state not in ('assigned','mitigation') or jsonb_typeof(p_requirements) is distinct from 'array' or jsonb_array_length(p_requirements) = 0 then raise invalid_parameter_value using message = 'Configure a nonempty plan before verification'; end if;
  if i.source = 'laboratory' then
    select indicator,method into required_indicator,required_method from public.test_results where id = i.source_id;
    if exists (select 1 from unnest(i.point_ids) point where not exists (select 1 from jsonb_array_elements(p_requirements) r where r->>'kind' = 'sample' and (r->>'point_id')::uuid = point and r->>'indicator' = required_indicator and r->>'method' = required_method)) then raise invalid_parameter_value using message = 'Follow-up must cover every affected point with the original indicator and method'; end if;
  end if;
  select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) into original from public.verification_requirements v where incident_id = i.id;
  delete from public.verification_requirements where incident_id = i.id;
  for q in select * from jsonb_array_elements(p_requirements) loop
    insert into public.verification_requirements(organization_id,facility_id,incident_id,kind,point_id,template_id,indicator,method,not_before,is_simulated)
      values(i.organization_id,i.facility_id,i.id,q->>'kind',(q->>'point_id')::uuid,(q->>'template_id')::uuid,q->>'indicator',q->>'method',private.record_time(i.organization_id),i.is_simulated);
  end loop;
  update public.incidents set version = version+1 where id = i.id;
  perform private.audit(i.organization_id,i.facility_id,i.id::text,i.state::text,'verification_plan_configured',p_reason,i.is_simulated,jsonb_build_object('previous',original,'requirements',p_requirements));
  return i.version+1;
end;
$$;
revoke all on function public.set_verification_plan from public, anon;
grant execute on function public.set_verification_plan to authenticated;

create function public.transition_incident(p_id uuid, p_target public.incident_state, p_expected_version integer, p_payload jsonb, p_reason text)
returns integer language plpgsql security definer set search_path = '' as $$
declare i public.incidents; at_time timestamptz; allowed boolean; owner uuid; action_at timestamptz;
begin
  select * into i from public.incidents where id = p_id for update;
  if not found then raise insufficient_privilege using message = 'Incident unavailable'; end if;
  perform private.require_member(i.organization_id,i.facility_id,array['manager','admin']::public.member_role[]);
  if i.version is distinct from p_expected_version then raise serialization_failure using message = 'Incident version conflict'; end if;
  allowed := case i.state when 'reported' then p_target = 'triaged' when 'triaged' then p_target = 'assigned'
    when 'assigned' then p_target in ('mitigation','verification_pending') when 'mitigation' then p_target = 'verification_pending'
    when 'verification_pending' then p_target in ('resolved','reopened') when 'resolved' then p_target = 'reopened' when 'reopened' then p_target = 'triaged' else false end;
  if not coalesce(allowed,false) then raise invalid_parameter_value using message = 'Invalid incident transition'; end if;
  at_time := private.record_time(i.organization_id);
  if p_target = 'triaged' and (coalesce(p_payload->>'priority','') not in ('routine','urgent','critical') or coalesce(length(btrim(p_payload->>'uncertainty')),0) = 0) then raise invalid_parameter_value using message = 'Urgency and uncertainty required'; end if;
  if p_target = 'assigned' then
    owner := (p_payload->>'owner_id')::uuid;
    if owner is null or p_payload->>'due_at' is null or (p_payload->>'due_at')::timestamptz <= at_time or coalesce(length(btrim(p_payload->>'required_response')),0) = 0 or not exists (select 1 from public.memberships m where m.user_id = owner and m.organization_id = i.organization_id and m.facility_id = i.facility_id and m.status = 'active' and (m.valid_until is null or m.valid_until > now())) then raise invalid_parameter_value using message = 'Active accountable owner, future deadline and response required'; end if;
  end if;
  if p_target = 'mitigation' and not exists (select 1 from public.work_orders w where w.incident_id = i.id and w.approved_by is not null and w.state in ('assigned','in_progress','completed','accepted','rework')) then raise invalid_parameter_value using message = 'Authorized work required'; end if;
  if p_target = 'verification_pending' then
    select max(a.occurred_at) into action_at from public.audit_events a join public.work_orders w on a.aggregate_id = w.id::text where w.incident_id = i.id and w.state = 'accepted' and a.new_state = 'completed';
    if action_at is null or coalesce((p_payload->>'controls_reviewed')::boolean,false) = false or coalesce((p_payload->>'notice_reviewed')::boolean,false) = false or coalesce(length(btrim(p_payload->>'notice_ref')),0) = 0 or not exists (select 1 from public.verification_requirements where incident_id = i.id) then raise invalid_parameter_value using message = 'Accepted work, reviewed controls, notice and verification plan required'; end if;
    if i.source = 'laboratory' and exists (select 1 from unnest(i.point_ids) point where not exists (select 1 from public.verification_requirements v join public.test_results r on r.id = i.source_id where v.incident_id = i.id and v.kind = 'sample' and v.point_id = point and v.indicator = r.indicator and v.method = r.method)) then raise invalid_parameter_value using message = 'Incomplete follow-up sampling plan'; end if;
    update public.verification_requirements set not_before = greatest(not_before,action_at) where incident_id = i.id;
  end if;
  if p_target = 'resolved' then
    if coalesce(length(btrim(p_payload->>'communication_ref')),0) = 0 or not exists (select 1 from public.verification_requirements where incident_id = i.id) then raise invalid_parameter_value using message = 'Verification plan and recorded communication required'; end if;
    if exists (
      select 1 from public.verification_requirements v where v.incident_id = i.id and (
        (v.kind = 'sample' and not exists (
          select 1 from public.samples s join public.test_results r on r.sample_id = s.id
          where s.organization_id = i.organization_id and s.facility_id = i.facility_id and s.point_id = v.point_id
            and s.collected_at >= v.not_before and s.collected_at >= at_time-v.fresh_for
            and r.state in ('reviewed','published') and r.source = 'laboratory' and r.value = 0
            and r.indicator = v.indicator and r.method = v.method and r.reviewed_at <= at_time
            and r.report_ref is not null and r.reviewed_by is not null and r.is_simulated = i.is_simulated
            and exists (select 1 from public.memberships m where m.user_id = r.reviewed_by and m.organization_id = i.organization_id and m.facility_id = i.facility_id and m.role = 'lab' and m.status = 'active' and (m.valid_until is null or m.valid_until > now()))
        )) or (v.kind = 'checklist' and not exists (
          select 1 from public.inspections inspection where inspection.organization_id = i.organization_id and inspection.facility_id = i.facility_id and inspection.template_id = v.template_id
            and inspection.state = 'submitted' and inspection.received_at between v.not_before and at_time
            and inspection.observed_at between v.not_before and inspection.received_at and inspection.is_simulated = i.is_simulated
            and not exists (select 1 from jsonb_each(inspection.answers) a where a.value->>'choice' in ('yes','unknown'))
        ))
      )
    ) then raise invalid_parameter_value using message = 'Verification requirements not fulfilled by current, valid, in-scope reviewed evidence'; end if;
  end if;
  if p_target = 'reopened' then
    if coalesce(p_payload->>'cause','') not in ('repeat_verified_finding','new_evidence','invalidated_verification') or coalesce(length(btrim(p_payload->>'evidence_ref')),0) = 0 then raise invalid_parameter_value using message = 'New or invalidated verification evidence required'; end if;
    if p_payload->>'cause' = 'repeat_verified_finding' and not exists (select 1 from public.test_results r join public.samples s on s.id = r.sample_id where r.id::text = p_payload->>'evidence_ref' and r.organization_id = i.organization_id and r.facility_id = i.facility_id and s.point_id = any(i.point_ids) and r.state in ('reviewed','published') and r.source = 'laboratory' and r.value > 0 and r.reviewed_at >= coalesce(i.resolved_at,i.reported_at) and r.is_simulated = i.is_simulated) then raise invalid_parameter_value using message = 'Repeat finding must be reviewed and in scope'; end if;
  end if;
  update public.incidents set state = p_target, version = version+1,
    priority = case when p_target = 'triaged' then p_payload->>'priority' else priority end,
    uncertainty = case when p_target = 'triaged' then p_payload->>'uncertainty' else uncertainty end,
    owner_id = case when p_target = 'assigned' then owner else owner_id end,
    due_at = case when p_target = 'assigned' then (p_payload->>'due_at')::timestamptz else due_at end,
    required_response = case when p_target = 'assigned' then p_payload->>'required_response' else required_response end,
    action_evidence = case when p_target in ('mitigation','verification_pending') then (select id::text from public.work_orders where incident_id = i.id and approved_by is not null order by due_at desc limit 1) else action_evidence end,
    resolved_at = case when p_target = 'resolved' then at_time else resolved_at end,
    communication_ref = case when p_target = 'resolved' then p_payload->>'communication_ref' else communication_ref end where id = i.id;
  perform private.audit(i.organization_id,i.facility_id,i.id::text,i.state::text,p_target::text,p_reason,i.is_simulated,jsonb_build_array(p_payload->>'communication_ref',p_payload->>'evidence_ref',p_payload->>'notice_ref'));
  return i.version+1;
end;
$$;
revoke all on function public.transition_incident from public, anon;
grant execute on function public.transition_incident to authenticated;

create function public.escalate_incident(p_id uuid, p_expected_version integer, p_reason text) returns integer
language plpgsql security definer set search_path = '' as $$
declare i public.incidents; at_time timestamptz;
begin
  select * into i from public.incidents where id = p_id for update;
  if not found then raise insufficient_privilege using message = 'Incident unavailable'; end if;
  perform private.require_member(i.organization_id,i.facility_id,array['manager','admin']::public.member_role[]);
  if i.version is distinct from p_expected_version then raise serialization_failure using message = 'Incident version conflict'; end if;
  at_time := private.record_time(i.organization_id);
  if i.state = 'resolved' or not coalesce(i.priority = 'critical' or i.due_at <= at_time,false) then raise invalid_parameter_value using message = 'Escalation requires an active critical issue or elapsed deadline'; end if;
  update public.incidents set escalated_at = at_time,version = version+1 where id = i.id;
  perform private.audit(i.organization_id,i.facility_id,i.id::text,i.state::text,'escalated',p_reason,i.is_simulated);
  return i.version+1;
end;
$$;
revoke all on function public.escalate_incident from public, anon;
grant execute on function public.escalate_incident to authenticated;

create function public.revoke_public_record(p_token text, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare qr public.public_records;
begin
  select * into qr from public.public_records where token = p_token for update;
  if not found then raise insufficient_privilege using message = 'QR unavailable'; end if;
  perform private.require_member(qr.organization_id,qr.facility_id,array['manager','admin']::public.member_role[]);
  if qr.revoked_at is not null then return; end if;
  update public.public_records set revoked_at = private.record_time(qr.organization_id) where id = qr.id;
  perform private.audit(qr.organization_id,qr.facility_id,qr.token,'active','revoked',p_reason,qr.is_simulated,jsonb_build_array(qr.point_id));
end;
$$;
revoke all on function public.revoke_public_record from public, anon;
grant execute on function public.revoke_public_record to authenticated;
