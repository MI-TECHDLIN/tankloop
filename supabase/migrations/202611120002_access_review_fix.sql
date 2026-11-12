-- Fix ambiguous column reference in review_access_request.
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
    if exists (select 1 from public.memberships m
      where m.user_id = request.user_id and m.organization_id = request.organization_id
        and m.facility_id = request.facility_id and m.role = request.requested_role and m.status = 'active') then
      raise invalid_parameter_value using message = 'An active membership already exists for this role';
    end if;
    insert into public.memberships(user_id, organization_id, facility_id, role, status, is_simulated)
      values (request.user_id, request.organization_id, request.facility_id, request.requested_role, 'active', facility.is_simulated);
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
