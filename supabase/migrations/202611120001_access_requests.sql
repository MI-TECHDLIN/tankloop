-- Self-service access requests: authenticated users request a scoped
-- membership; an organization admin approves or rejects it. Direct table
-- writes stay revoked; all mutations go through these constrained RPCs.
create table public.access_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  facility_id uuid not null,
  user_id uuid not null references auth.users(id),
  email text not null,
  requested_role public.member_role not null check (requested_role in ('field','manager','lab')),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  decision_reason text,
  is_simulated boolean not null default false,
  created_at timestamptz not null default now(),
  foreign key (organization_id, facility_id) references public.facilities(organization_id, id)
);
create unique index access_requests_pending_unique
  on public.access_requests(user_id, facility_id, requested_role) where status = 'pending';
create index access_requests_scope
  on public.access_requests(organization_id, facility_id) where status = 'pending';

alter table public.access_requests enable row level security;
revoke all on public.access_requests from anon, authenticated;
grant select on public.access_requests to authenticated;
create policy own_access_requests on public.access_requests for select to authenticated
  using (user_id = auth.uid());
create policy admin_access_requests on public.access_requests for select to authenticated
  using (private.has_membership(organization_id, facility_id, array['admin']::public.member_role[]));

-- Facilities open to self-service requests. Simulated demo facilities only;
-- real facilities are onboarded through administrator provisioning instead.
create function public.list_joinable_facilities() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise insufficient_privilege using message = 'Sign-in required'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'facility_id', f.id,
      'label', f.public_label,
      'organization', o.name,
      'timezone', f.timezone
    ) order by o.name, f.public_label)
    from public.facilities f
    join public.organizations o on o.id = f.organization_id
    where f.is_simulated
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.list_joinable_facilities from public, anon;
grant execute on function public.list_joinable_facilities to authenticated;

create function public.request_access(p_facility_id uuid, p_role public.member_role)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  facility public.facilities;
  existing uuid;
  requester_email text;
  request_id uuid;
begin
  if auth.uid() is null then raise insufficient_privilege using message = 'Sign-in required'; end if;
  if p_role is null or p_role = 'admin' then
    raise invalid_parameter_value using message = 'Request a field, manager or laboratory role';
  end if;
  select * into facility from public.facilities where id = p_facility_id;
  if not found or not facility.is_simulated then
    raise invalid_parameter_value using message = 'Facility is not open for self-service access';
  end if;
  select email into requester_email from auth.users where id = auth.uid();
  select id into existing from public.access_requests
    where user_id = auth.uid() and facility_id = p_facility_id
      and requested_role = p_role and status = 'pending';
  if found then return existing; end if;
  if exists (select 1 from public.memberships m
    where m.user_id = auth.uid() and m.organization_id = facility.organization_id
      and m.facility_id = p_facility_id and m.role = p_role and m.status = 'active') then
    raise invalid_parameter_value using message = 'This access is already active';
  end if;
  insert into public.access_requests(organization_id, facility_id, user_id, email, requested_role, is_simulated)
  values (facility.organization_id, facility.id, auth.uid(), coalesce(requester_email,''), p_role, facility.is_simulated)
  returning id into request_id;
  perform private.audit(facility.organization_id, facility.id, request_id::text, 'none', 'pending',
    'Access requested: ' || p_role::text, facility.is_simulated);
  return request_id;
end;
$$;
revoke all on function public.request_access from public, anon;
grant execute on function public.request_access to authenticated;

create function public.review_access_request(p_request_id uuid, p_approve boolean, p_reason text default null)
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
