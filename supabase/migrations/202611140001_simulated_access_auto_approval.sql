-- Simulated demo facilities approve self-service access immediately so the
-- signup path cannot dead-end before an administrator exists. Non-simulated
-- facilities still create pending requests for organization administrator
-- review through review_access_request.
create or replace function public.request_access(p_facility_id uuid, p_role public.member_role)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  facility public.facilities;
  existing uuid;
  requester_email text;
  request_id uuid;
  v_now timestamptz;
begin
  if auth.uid() is null then raise insufficient_privilege using message = 'Sign-in required'; end if;
  if p_role is null or p_role = 'admin' then
    raise invalid_parameter_value using message = 'Request a field, manager or laboratory role';
  end if;
  select * into facility from public.facilities where id = p_facility_id;
  if not found then
    raise invalid_parameter_value using message = 'Facility is not open for self-service access';
  end if;
  v_now := private.record_time(facility.organization_id);
  select email into requester_email from auth.users where id = auth.uid();
  select id into existing from public.access_requests
    where user_id = auth.uid() and facility_id = p_facility_id
      and requested_role = p_role and status = 'pending';
  if found then return existing; end if;
  if exists (select 1 from public.memberships m
    where m.user_id = auth.uid() and m.organization_id = facility.organization_id
      and m.facility_id = p_facility_id and m.role = p_role and m.status = 'active'
      and (m.valid_until is null or m.valid_until > now())) then
    raise invalid_parameter_value using message = 'This access is already active';
  end if;
  if facility.is_simulated then
    insert into public.access_requests(
      organization_id, facility_id, user_id, email, requested_role, status,
      decided_at, decision_reason, is_simulated, created_at
    ) values (
      facility.organization_id, facility.id, auth.uid(), coalesce(requester_email,''),
      p_role, 'approved', v_now, 'Automatic approval for simulated demo access',
      facility.is_simulated, v_now
    ) returning id into request_id;
    insert into public.memberships(user_id, organization_id, facility_id, role, status, is_simulated)
    values (auth.uid(), facility.organization_id, facility.id, p_role, 'active', facility.is_simulated)
    on conflict (user_id, organization_id, facility_id, role)
    do update set status = 'active', valid_until = null, is_simulated = excluded.is_simulated;
    perform private.audit(facility.organization_id, facility.id, request_id::text, 'none', 'approved',
      'Access auto-approved: ' || p_role::text || ' - simulated demo facility', facility.is_simulated);
  else
    insert into public.access_requests(
      organization_id, facility_id, user_id, email, requested_role, is_simulated, created_at
    ) values (
      facility.organization_id, facility.id, auth.uid(), coalesce(requester_email,''),
      p_role, facility.is_simulated, v_now
    ) returning id into request_id;
    perform private.audit(facility.organization_id, facility.id, request_id::text, 'none', 'pending',
      'Access requested: ' || p_role::text, facility.is_simulated);
  end if;
  return request_id;
end;
$$;
revoke all on function public.request_access from public, anon;
grant execute on function public.request_access to authenticated;

-- Keep administrator approval on the same membership semantics: expired or
-- revoked grants can be reactivated, and expiry is checked with real time.
create or replace function public.review_access_request(p_request_id uuid, p_approve boolean, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  request public.access_requests;
  facility public.facilities;
  v_decided_at timestamptz;
begin
  select * into request from public.access_requests where id = p_request_id for update;
  if not found then raise invalid_parameter_value using message = 'Access request unavailable'; end if;
  if not private.has_membership(request.organization_id, request.facility_id, array['admin']::public.member_role[]) then
    raise insufficient_privilege using message = 'Organization administrator approval required';
  end if;
  if request.status <> 'pending' then raise invalid_parameter_value using message = 'Access request already decided'; end if;
  if request.user_id = auth.uid() then raise insufficient_privilege using message = 'Administrators cannot decide their own request'; end if;
  select * into facility from public.facilities where id = request.facility_id;
  v_decided_at := private.record_time(request.organization_id);
  if p_approve then
    insert into public.memberships(user_id, organization_id, facility_id, role, status, is_simulated)
      values (request.user_id, request.organization_id, request.facility_id, request.requested_role, 'active', facility.is_simulated)
      on conflict (user_id, organization_id, facility_id, role)
      do update set status = 'active', valid_until = null, is_simulated = excluded.is_simulated;
    update public.access_requests set status = 'approved', decided_by = auth.uid(), decided_at = v_decided_at,
      decision_reason = nullif(btrim(coalesce(p_reason,'')),'') where id = request.id returning * into request;
    perform private.audit(request.organization_id, request.facility_id, request.id::text, 'pending', 'approved',
      'Access approved: ' || request.requested_role::text || coalesce(' - ' || p_reason, ''), facility.is_simulated);
  else
    if p_reason is null or length(btrim(p_reason)) = 0 then
      raise invalid_parameter_value using message = 'A reason is required when rejecting access';
    end if;
    update public.access_requests set status = 'rejected', decided_by = auth.uid(), decided_at = v_decided_at,
      decision_reason = btrim(p_reason) where id = request.id returning * into request;
    perform private.audit(request.organization_id, request.facility_id, request.id::text, 'pending', 'rejected',
      'Access rejected: ' || request.requested_role::text || ' - ' || btrim(p_reason), facility.is_simulated);
  end if;
  return to_jsonb(request);
end;
$$;
revoke all on function public.review_access_request from public, anon;
grant execute on function public.review_access_request to authenticated;
