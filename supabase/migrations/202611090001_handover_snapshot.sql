-- A read-only, bounded projection. Invoker rights retain every existing RLS
-- boundary. Free-text notes, contacts, attachments and report URLs never leave
-- this boundary. Content hashes also detect edits to fields not projected here.
create function public.handover_snapshot(p_kind text, p_id uuid)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  v_org uuid;
  v_facility uuid;
  v_label text;
  v_points uuid[];
  v_sources jsonb;
  v_counts jsonb;
begin
  if p_kind = 'point' then
    select organization_id, facility_id, label, array[id]
      into v_org, v_facility, v_label, v_points
      from public.sampling_points where id = p_id and not is_simulated;
  elsif p_kind = 'incident' then
    select organization_id, facility_id, 'Case record', point_ids
      into v_org, v_facility, v_label, v_points
      from public.incidents where id = p_id and not is_simulated;
  else
    raise invalid_parameter_value using message = 'Choose a point or incident';
  end if;
  if v_org is null or not private.has_membership(v_org, v_facility,
      array['field','manager','admin']::public.member_role[]) then
    raise insufficient_privilege using message = 'Selected records unavailable';
  end if;

  with points as materialized (
    select p.* from public.sampling_points p
    where p.id = any(v_points) and p.organization_id = v_org
      and p.facility_id = v_facility and not p.is_simulated
  ), cases as materialized (
    select i.* from public.incidents i
    where i.organization_id = v_org and i.facility_id = v_facility
      and not i.is_simulated and
      case when p_kind = 'incident' then i.id = p_id
        else i.point_ids @> array[p_id] end
  ), records as (
    select 'point'::text as kind, p.id, md5(to_jsonb(p)::text) as revision,
      '-infinity'::timestamptz as sort_date,
      jsonb_build_object('label', left(p.label,160), 'asset_id', p.asset_id) as fields
    from points p
    union all
    select 'inspection', i.id, md5(to_jsonb(i)::text), coalesce(i.observed_at, i.due_at),
      jsonb_build_object('state',i.state,'due_at',i.due_at,
        'observed_at',i.observed_at,'received_at',i.received_at,'version',i.version,
        'has_assignee',i.assigned_to is not null,'asset_id',i.asset_id)
    from public.inspections i
    where i.organization_id = v_org and i.facility_id = v_facility
      and not i.is_simulated and i.asset_id in (select asset_id from points)
    union all
    select 'incident', i.id, md5(to_jsonb(i)::text), i.reported_at,
      jsonb_build_object('state',i.state,'source',i.source,'reported_at',i.reported_at,
        'due_at',i.due_at,'version',i.version,'has_owner',i.owner_id is not null,
        'resolved_at',i.resolved_at)
    from cases i
    union all
    select 'work_order', w.id, md5(to_jsonb(w)::text), coalesce(w.due_at,'-infinity'),
      jsonb_build_object('state',w.state,'due_at',w.due_at,'version',w.version,
        'incident_id',w.incident_id,'has_assignee',w.assignee_id is not null)
    from public.work_orders w
    where w.organization_id = v_org and w.facility_id = v_facility
      and not w.is_simulated and w.incident_id in (select id from cases)
    union all
    select 'result', r.id, md5((to_jsonb(r) || jsonb_build_object('sample',to_jsonb(s)))::text),
      coalesce(r.tested_at,s.collected_at),
      jsonb_build_object('state',r.state,'source',r.source,'version',r.version,
        'point_id',s.point_id,'collected_at',s.collected_at,'tested_at',r.tested_at,
        'reviewed_at',r.reviewed_at,'published_at',r.published_at,
        'indicator',r.indicator,'value',r.value::text,'units',r.units,
        'detection_limit',r.detection_limit::text)
    from public.test_results r join public.samples s on s.id = r.sample_id
      and s.organization_id = r.organization_id and s.facility_id = r.facility_id
    where r.organization_id = v_org and r.facility_id = v_facility
      and not r.is_simulated and not s.is_simulated and s.point_id in (select id from points)
    union all
    select 'requirement', v.id, md5(to_jsonb(v)::text), v.not_before,
      jsonb_build_object('kind',v.kind,'incident_id',v.incident_id,
        'not_before',v.not_before,'fresh_for',v.fresh_for::text)
    from public.verification_requirements v
    where v.organization_id = v_org and v.facility_id = v_facility
      and not v.is_simulated and v.incident_id in (select id from cases)
  ), ranked as (
    select *, row_number() over (partition by kind order by sort_date desc, id) as position
    from records
  )
  select
    coalesce((select jsonb_agg(jsonb_build_object('id',kind||':'||id::text,
      'record_id',id,'kind',kind,'revision',revision,'is_simulated',false,'fields',fields)
      order by kind, position) from ranked where position <= 8),'[]'::jsonb),
    coalesce((select jsonb_object_agg(kind,total) from
      (select kind, count(*) as total from records group by kind) totals),'{}'::jsonb)
  into v_sources, v_counts;
  return jsonb_build_object('kind',p_kind,'id',p_id,'label',left(v_label,160),
    'organization_id',v_org,'facility_id',v_facility,'sources',v_sources,
    'counts',v_counts,'limit_per_kind',8);
end;
$$;
revoke all on function public.handover_snapshot(text,uuid) from public, anon;
grant execute on function public.handover_snapshot(text,uuid) to authenticated;
