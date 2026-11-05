-- Read-only manager projection. Every relation is scoped to the authorized
-- facility in one statement snapshot; membership authority is never client-set.
create function public.manager_workspace(p_facility_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare f public.facilities; allowed_facilities jsonb; records jsonb;
begin
  select * into f from public.facilities
  where (p_facility_id is null or id = p_facility_id)
    and private.has_membership(organization_id, id, array['manager','admin']::public.member_role[])
  order by id limit 1;
  if not found then
    raise insufficient_privilege using message = 'An active, scoped manager or administrator membership is required';
  end if;

  select jsonb_agg(to_jsonb(allowed) order by allowed.public_label, allowed.id)
  into allowed_facilities from public.facilities allowed
  where private.has_membership(allowed.organization_id, allowed.id, array['manager','admin']::public.member_role[]);

  select coalesce(jsonb_agg(to_jsonb(r) || jsonb_build_object(
    'sample', to_jsonb(s), 'point_label', p.label,
    'custody', (select coalesce(jsonb_agg(to_jsonb(c) order by c.occurred_at, c.id), '[]'::jsonb)
      from public.custody_events c where c.organization_id = f.organization_id and c.facility_id = f.id and c.sample_id = s.id),
    'audit', (select coalesce(jsonb_agg(to_jsonb(a) order by a.occurred_at, a.id), '[]'::jsonb)
      from public.audit_events a where a.organization_id = f.organization_id and a.facility_id = f.id and a.aggregate_id = r.id::text),
    'open_incident_count', (select count(*) from public.incidents i
      where i.organization_id = f.organization_id and i.facility_id = f.id and p.id = any(i.point_ids) and i.state <> 'resolved')
    ) order by s.collected_at desc, r.id), '[]'::jsonb)
  into records from public.test_results r
    join public.samples s on s.id = r.sample_id and s.organization_id = r.organization_id and s.facility_id = r.facility_id
    join public.sampling_points p on p.id = s.point_id and p.organization_id = s.organization_id and p.facility_id = s.facility_id
  where r.organization_id = f.organization_id and r.facility_id = f.id;

  return jsonb_build_object(
    'facility', to_jsonb(f), 'facilities', allowed_facilities, 'actor_id', auth.uid(),
    'as_of', private.record_time(f.organization_id), 'fetched_at', statement_timestamp(),
    'simulation', (select jsonb_build_object('simulation_seed', settings->'simulation_seed', 'model_version', settings->'model_version')
      from public.organizations where id = f.organization_id),
    'systems', (select coalesce(jsonb_agg(to_jsonb(s) order by s.label, s.id), '[]'::jsonb)
      from public.water_systems s where s.organization_id = f.organization_id and s.facility_id = f.id),
    'assets', (select coalesce(jsonb_agg(to_jsonb(a) order by a.label, a.id), '[]'::jsonb)
      from public.assets a where a.organization_id = f.organization_id and a.facility_id = f.id),
    'points', (select coalesce(jsonb_agg(to_jsonb(p) order by p.label, p.id), '[]'::jsonb)
      from public.sampling_points p where p.organization_id = f.organization_id and p.facility_id = f.id),
    'templates', (select coalesce(jsonb_agg(to_jsonb(t) order by t.title, t.version), '[]'::jsonb)
      from public.checklist_templates t where t.organization_id = f.organization_id and t.facility_id = f.id),
    'inspections', (select coalesce(jsonb_agg(to_jsonb(i) order by i.due_at, i.id), '[]'::jsonb)
      from public.inspections i where i.organization_id = f.organization_id and i.facility_id = f.id),
    'samples', (select coalesce(jsonb_agg(to_jsonb(s) || jsonb_build_object(
      'custody', (select coalesce(jsonb_agg(to_jsonb(c) order by c.occurred_at, c.id), '[]'::jsonb)
        from public.custody_events c where c.organization_id = f.organization_id and c.facility_id = f.id and c.sample_id = s.id)
      ) order by s.collected_at desc, s.id), '[]'::jsonb)
      from public.samples s where s.organization_id = f.organization_id and s.facility_id = f.id),
    'records', records,
    'incidents', (select coalesce(jsonb_agg(to_jsonb(i) || jsonb_build_object(
      'requirements', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
        from public.verification_requirements v where v.organization_id = f.organization_id and v.facility_id = f.id and v.incident_id = i.id)
      ) order by i.reported_at desc, i.id), '[]'::jsonb)
      from public.incidents i where i.organization_id = f.organization_id and i.facility_id = f.id),
    'work_orders', (select coalesce(jsonb_agg(to_jsonb(w) order by w.due_at, w.id), '[]'::jsonb)
      from public.work_orders w where w.organization_id = f.organization_id and w.facility_id = f.id),
    -- A scoped manager can review the roster, including expired/revoked grants.
    -- No auth.users join: credentials, email addresses and profiles stay private.
    'memberships', (select coalesce(jsonb_agg(to_jsonb(m) order by m.role, m.id), '[]'::jsonb)
      from public.memberships m where m.organization_id = f.organization_id
        and (m.facility_id = f.id or (m.facility_id is null and m.role = 'admin'))),
    'qrs', (select coalesce(jsonb_agg(to_jsonb(q) order by q.issued_at, q.id), '[]'::jsonb)
      from public.public_records q where q.organization_id = f.organization_id and q.facility_id = f.id),
    'audit', (select coalesce(jsonb_agg(to_jsonb(a) order by a.occurred_at, a.id), '[]'::jsonb)
      from public.audit_events a where a.organization_id = f.organization_id and a.facility_id = f.id)
  );
end;
$$;
revoke all on function public.manager_workspace from public, anon;
grant execute on function public.manager_workspace to authenticated;
