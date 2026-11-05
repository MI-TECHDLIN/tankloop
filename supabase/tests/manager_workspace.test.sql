-- Exercise the manager projection and existing commands as real PostgREST roles.
-- All fixtures, grants and mutations are confined to this rolled-back transaction.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into organizations(id, name, settings, is_simulated) values
 ('c1000000-0000-4000-8000-000000000001', 'Manager contract A', '{"simulation_clock":"2026-11-10T12:00:00Z","simulation_seed":20261101,"model_version":1}', true),
 ('c1000000-0000-4000-8000-000000000002', 'Manager contract B', '{"simulation_clock":"2026-11-10T12:00:00Z"}', true);
insert into facilities(id, organization_id, public_label, is_simulated) values
 ('c2000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'Assigned manager facility', true),
 ('c2000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001', 'Sibling facility', true),
 ('c2000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000002', 'Other tenant', true),
 ('c2000000-0000-4000-8000-000000000004', 'c1000000-0000-4000-8000-000000000001', 'Empty assigned facility', true);
insert into auth.users(id, email)
 select ('c9000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
   'manager-contract-' || n || '@tankloop.invalid' from generate_series(1, 13) n;
insert into memberships(user_id, organization_id, facility_id, role, status, valid_until, is_simulated) values
 ('c9000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'field', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'lab', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'manager', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000004', 'c1000000-0000-4000-8000-000000000001', null, 'admin', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000005', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000002', 'manager', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000006', 'c1000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000003', 'manager', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000007', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'manager', 'revoked', null, true),
 ('c9000000-0000-4000-8000-000000000008', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'manager', 'active', now() - interval '1 day', true),
 ('c9000000-0000-4000-8000-000000000009', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'manager', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000009', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000002', 'manager', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000011', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'admin', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000012', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000002', 'field', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000013', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'manager', 'active', now() + interval '1 hour', true);
insert into water_systems(id, organization_id, facility_id, label, is_simulated)
 select replace(id::text, 'c2000000', 'c3000000')::uuid, organization_id, id, 'Contract network', true
 from facilities where id in ('c2000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000003');
insert into assets(id, organization_id, facility_id, system_id, type, label, capacity_litres, is_simulated)
 select replace(id::text, 'c3000000', 'c4000000')::uuid, organization_id, facility_id, id, 'tank', 'Contract tank', 1200, true
 from water_systems where id::text like 'c3000000-%';
insert into assets(id, organization_id, facility_id, system_id, parent_asset_id, type, label, retired_at, is_simulated)
 values ('c4000000-0000-4000-8000-000000000004', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001',
   'c3000000-0000-4000-8000-000000000001', 'c4000000-0000-4000-8000-000000000001', 'tap', 'Retired downstream tap', '2026-11-09T12:00:00Z', true);
insert into sampling_points(id, organization_id, facility_id, asset_id, label, is_simulated)
 select replace(id::text, 'c4000000', 'c5000000')::uuid, organization_id, facility_id, id, 'Contract outlet', true
 from assets where id::text like 'c4000000-%' and retired_at is null;
insert into checklist_templates(id, organization_id, facility_id, version, title, source, asset_type, questions, is_simulated)
 select replace(id::text, 'c3000000', 'c6000000')::uuid, organization_id, facility_id, 1, 'Contract tank checklist', 'Simulation contract checklist', 'tank',
   '[{"id":"cover","label":"Is the cover damaged?","required":true,"source_id":"contract-cover"}]'::jsonb, true
 from water_systems where id::text like 'c3000000-%';
insert into inspections(id, organization_id, facility_id, asset_id, template_id, assigned_to, submitted_by, due_at, observed_at, received_at, state, answers, notes, version, is_simulated)
 select replace(id::text, 'c6000000', 'c6100000')::uuid, organization_id, facility_id, replace(id::text, 'c6000000', 'c4000000')::uuid, id,
   'c9000000-0000-4000-8000-000000000001', 'c9000000-0000-4000-8000-000000000001', '2026-11-10T10:00:00Z', '2026-11-10T09:00:00Z', '2026-11-10T11:00:00Z',
   'submitted', '{"cover":{"choice":"yes","note":"Recorded damage"}}'::jsonb, 'Simulated inspection evidence', 1, true
 from checklist_templates where id::text like 'c6000000-%';
insert into samples(id, code, organization_id, facility_id, point_id, collector_id, collected_at, intended_method, preservation_note, is_simulated)
 select replace(id::text, 'c5000000', 'c7000000')::uuid, 'MANAGER-' || id::text, organization_id, facility_id, id,
   'c9000000-0000-4000-8000-000000000001', '2026-11-10T09:00:00Z', 'Membrane filtration', 'Simulated sealed handoff', true
 from sampling_points where id::text like 'c5000000-%';
insert into test_results(id, organization_id, facility_id, sample_id, state, indicator, method, value, units, detection_limit, received_at, tested_at, reviewed_at, reviewed_by, report_ref, version, is_simulated)
 select replace(id::text, 'c7000000', 'c7100000')::uuid, organization_id, facility_id, id, 'reviewed', 'e_coli', 'Membrane filtration', 0, 'mpn_per100ml', 0.5,
   '2026-11-10T10:00:00Z', '2026-11-10T11:00:00Z', '2026-11-10T12:00:00Z', 'c9000000-0000-4000-8000-000000000002', 'simulation://manager-report', 4, true
 from samples where id::text like 'c7000000-%';
insert into custody_events(id, organization_id, facility_id, sample_id, from_actor, to_actor, occurred_at, note, is_simulated)
 select replace(id::text, 'c7000000', 'c7200000')::uuid, organization_id, facility_id, id,
   'c9000000-0000-4000-8000-000000000001', 'c9000000-0000-4000-8000-000000000002', '2026-11-10T10:00:00Z', 'Simulated custody handoff', true
 from samples where id::text like 'c7000000-%';
insert into incidents(id, organization_id, facility_id, system_id, point_ids, source, source_id, reported_at, is_simulated)
 select replace(id::text, 'c6100000', 'c7300000')::uuid, organization_id, facility_id, replace(id::text, 'c6100000', 'c3000000')::uuid,
   array[replace(id::text, 'c6100000', 'c5000000')::uuid], 'inspection', id, '2026-11-10T11:00:00Z', true
 from inspections where id::text like 'c6100000-%';
insert into work_orders(id, organization_id, facility_id, incident_id, task, state, version, is_simulated)
 select replace(id::text, 'c7300000', 'c7400000')::uuid, organization_id, facility_id, id, 'Inspect the recorded cover damage', 'approval_pending', 1, true
 from incidents where id::text like 'c7300000-%';
insert into public_records(id, organization_id, facility_id, point_id, token, issued_at, is_simulated)
 select replace(id::text, 'c5000000', 'c7600000')::uuid, organization_id, facility_id, id, replace(id::text, '-', ''), '2026-11-01T00:00:00Z', true
 from sampling_points where id::text like 'c5000000-%';
insert into audit_events(id, organization_id, facility_id, aggregate_id, actor_id, occurred_at, previous_state, new_state, reason, is_simulated)
 select replace(id::text, 'c7100000', 'c7700000')::uuid, organization_id, facility_id, id::text, reviewed_by, reviewed_at, 'tested', 'reviewed', 'Simulated review provenance', true
 from test_results where id::text like 'c7100000-%';
-- Aggregate IDs are text, so deliberately collide across scopes to test nested audits.
insert into audit_events(organization_id, facility_id, aggregate_id, actor_id, previous_state, new_state, reason, is_simulated)
 select organization_id, id, 'c7100000-0000-4000-8000-000000000001', 'c9000000-0000-4000-8000-000000000006', 'none', 'private', 'Hidden scope audit', true
 from facilities where id in ('c2000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000003');

set local request.jwt.claims = '{"role":"anon"}';
set local role anon;
select throws_ok($$select manager_workspace()$$, '42501', null, 'Anonymous manager projection is denied');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select manager_workspace()$$, '42501', null, 'Field membership does not grant a manager workspace');
select throws_ok($$select transition_result('c7100000-0000-4000-8000-000000000001', 'published', 4, '{}', 'Publish')$$, '42501', null, 'Field cannot publish a known reviewed result');
select throws_ok($$select transition_incident('c7300000-0000-4000-8000-000000000001', 'triaged', 0, '{"priority":"critical","uncertainty":"Scope limited"}', 'Triage')$$, '42501', null, 'Field cannot triage a known incident');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select manager_workspace()$$, '42501', null, 'Lab review authority does not grant the manager roster');
select throws_ok($$select transition_result('c7100000-0000-4000-8000-000000000001', 'published', 4, '{}', 'Publish')$$, '42501', null, 'Laboratory review and publication authority remain separate');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000005","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select manager_workspace('c2000000-0000-4000-8000-000000000001')$$, '42501', null, 'Sibling manager cannot open a known facility');
select throws_ok($$select transition_work_order('c7400000-0000-4000-8000-000000000001', 'assigned', 1, '{}', 'Approve')$$, '42501', null, 'Sibling manager cannot approve known work');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000006","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select manager_workspace('c2000000-0000-4000-8000-000000000001')$$, '42501', null, 'Manager projection enforces tenant boundaries');
select throws_ok($$select revoke_public_record('c5000000000040008000000000000001', 'Revoke')$$, '42501', null, 'Other tenant cannot revoke a known QR identity');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000007","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select manager_workspace()$$, '42501', null, 'Revoked manager cannot reload a workspace');
select throws_ok($$select transition_result('c7100000-0000-4000-8000-000000000001', 'published', 4, '{}', 'Delayed action')$$, '42501', null, 'Revoked manager cannot submit a previously opened action');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000008","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select manager_workspace()$$, '42501', null, 'Expired membership is denied using actual server time');
select throws_ok($$select escalate_incident('c7300000-0000-4000-8000-000000000001', 0, 'Escalate')$$, '42501', null, 'Expired manager cannot escalate');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000010","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select manager_workspace()$$, '42501', null, 'Authentication alone cannot expose manager records');
select throws_ok($$select set_verification_plan('c7300000-0000-4000-8000-000000000001', 0, '[]', 'Plan')$$, '42501', null, 'Unassigned account cannot write verification requirements');

reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000003","role":"authenticated"}';
set local role authenticated;
select lives_ok($$select set_config('manager.snapshot', manager_workspace()::text, true)$$, 'Active manager loads the typed projection');
select is(manager_workspace()->'facility'->>'id', 'c2000000-0000-4000-8000-000000000001', 'Default chooses an authorized facility');
select is(jsonb_array_length(manager_workspace()->'facilities'), 1, 'Facility picker exposes exactly the manager assignment');
select is(manager_workspace()->>'actor_id', auth.uid()::text, 'Actor identity comes from the authenticated session');
select is((manager_workspace()->>'as_of')::timestamptz, '2026-11-10T12:00:00Z'::timestamptz, 'Records retain the canonical simulation clock');
select is((manager_workspace()->>'fetched_at')::timestamptz, statement_timestamp(), 'Freshness uses actual read time');
select is(manager_workspace()->'simulation'->>'simulation_seed', '20261101', 'Projection carries the simulation seed');
select is(manager_workspace()->'simulation'->>'model_version', '1', 'Projection carries the simulation model version');
select is(jsonb_array_length(manager_workspace()->'assets'), 2, 'Facility includes retired downstream assets');
select is((select a->>'parent_asset_id' from jsonb_array_elements(manager_workspace()->'assets') a where a->>'type' = 'tap'), 'c4000000-0000-4000-8000-000000000001', 'Asset ancestry retains its immutable identity');
select is(jsonb_array_length(manager_workspace()->'memberships'), 9, 'Roster includes only scoped grants and the organization administrator');
select is((select count(*)::int from memberships), 1, 'Manager projection does not broaden direct membership RLS');
select ok(not exists (
 select 1 from unnest(array['systems','assets','points','templates','inspections','samples','records','incidents','work_orders','qrs','audit']) k,
   lateral jsonb_array_elements(current_setting('manager.snapshot')::jsonb->k) r
 where r->>'organization_id' <> 'c1000000-0000-4000-8000-000000000001' or r->>'facility_id' <> 'c2000000-0000-4000-8000-000000000001'
), 'Every projected relation remains in the selected tenant and facility');
select is(manager_workspace()->'inspections'->0->'answers'->'cover'->>'choice', 'yes', 'Inspection detail includes the submitted answer');
select is(manager_workspace()->'inspections'->0->>'submitted_by', 'c9000000-0000-4000-8000-000000000001', 'Inspection provenance identifies the submitting actor');
select is(manager_workspace()->'templates'->0->>'source', 'Simulation contract checklist', 'Checklist source is preserved');
select is(jsonb_array_length(manager_workspace()->'records'), 1, 'Sibling and other-tenant results are excluded');
select is(manager_workspace()->'records'->0->'sample'->>'preservation_note', 'Simulated sealed handoff', 'Nested sample retains transport evidence');
select is(manager_workspace()->'records'->0->'custody'->0->>'id', 'c7200000-0000-4000-8000-000000000001', 'Result custody contains only its scoped sample handoff');
select is(manager_workspace()->'samples'->0->'custody', manager_workspace()->'records'->0->'custody', 'Sample and result details share the same custody evidence');
select is(jsonb_array_length(manager_workspace()->'records'->0->'audit'), 1, 'Nested audit excludes deliberate cross-scope aggregate collisions');
select is(manager_workspace()->'records'->0->>'open_incident_count', '1', 'Open incidents are counted only at this point and scope');
select is(manager_workspace()->'records'->0->>'reviewed_by', 'c9000000-0000-4000-8000-000000000002', 'Manager sees the actual laboratory reviewer');
select is(manager_workspace()->'records'->0->>'units', 'mpn_per100ml', 'Exact laboratory units are preserved');
select ok(not exists (select 1 from jsonb_array_elements(manager_workspace()->'memberships') m where m ?| array['email','password','encrypted_password']), 'Roster does not expose authentication credentials or profiles');
select throws_ok($$update memberships set role = 'admin'$$, '42501', null, 'Roster visibility cannot grant membership mutation authority');
select throws_ok($$update test_results set reviewed_by = auth.uid()$$, '42501', null, 'Manager cannot impersonate a lab reviewer through table writes');
select throws_ok($$select transition_result('c7100000-0000-4000-8000-000000000001', 'reviewed', 4, '{"report_ref":"simulation://forged"}', 'Attest')$$, '42501', null, 'Manager cannot use the review RPC to self-attest');

select throws_ok($$select transition_result('c7100000-0000-4000-8000-000000000001', 'published', 4, '{}', ' ')$$, '22023', null, 'Publication requires an audit reason');
select is(manager_workspace()->'records'->0->>'state', 'reviewed', 'Failed publication is rolled back');
select is(transition_result('c7100000-0000-4000-8000-000000000001', 'published', 4, '{}', 'Reviewed date and scope'), 5, 'Manager publishes a reviewed result through the existing RPC');
select is(manager_workspace()->'records'->0->>'reviewed_by', 'c9000000-0000-4000-8000-000000000002', 'Publication retains laboratory attestation');
select is((select a->>'actor_id' from jsonb_array_elements(manager_workspace()->'records'->0->'audit') a where a->>'new_state' = 'published'), auth.uid()::text, 'Publication audit records the manager separately');
select throws_ok($$select transition_result('c7100000-0000-4000-8000-000000000001', 'published', 4, '{}', 'Retry old view')$$, '40001', null, 'Lost publication acknowledgement requires a fresh version');
select is(transition_incident('c7300000-0000-4000-8000-000000000001', 'triaged', 0, '{"priority":"critical","uncertainty":"Reported point only"}', 'Review inspection concern'), 1, 'Manager triages actual recorded evidence');
select throws_ok($$select transition_incident('c7300000-0000-4000-8000-000000000001', 'assigned', 1, '{"owner_id":"c9000000-0000-4000-8000-000000000012","due_at":"2026-11-11T12:00:00Z","required_response":"Inspect"}', 'Wrong scope')$$, '22023', null, 'An owner must hold an active assignment at the incident facility');
select is(transition_incident('c7300000-0000-4000-8000-000000000001', 'assigned', 1, '{"owner_id":"c9000000-0000-4000-8000-000000000001","due_at":"2026-11-11T12:00:00Z","required_response":"Inspect the cover"}', 'Assign accountable response'), 2, 'Manager assigns an active scoped owner and deadline');
select throws_ok($$select transition_work_order('c7400000-0000-4000-8000-000000000001', 'assigned', 1, '{"assignee_id":"c9000000-0000-4000-8000-000000000002","due_at":"2026-11-11T12:00:00Z"}', 'Assign lab')$$, '22023', null, 'Lab membership is not a field work assignment');
select is(transition_work_order('c7400000-0000-4000-8000-000000000001', 'assigned', 1, '{"assignee_id":"c9000000-0000-4000-8000-000000000001","due_at":"2026-11-11T12:00:00Z"}', 'Approve scoped maintenance'), 2, 'Manager approves work for the scoped field member');
select is(transition_incident('c7300000-0000-4000-8000-000000000001', 'mitigation', 2, '{}', 'Authorized work in place'), 3, 'Interim measure references approved work');
select throws_ok($$select set_verification_plan('c7300000-0000-4000-8000-000000000001', 3, '[{"kind":"checklist","template_id":"c6000000-0000-4000-8000-000000000002"}]', 'Wrong scope')$$, '23503', null, 'Verification requirements cannot reference a sibling template');
select is(set_verification_plan('c7300000-0000-4000-8000-000000000001', 3, '[{"kind":"checklist","template_id":"c6000000-0000-4000-8000-000000000001"}]', 'Require new inspection'), 4, 'Verification plan has its own audited version');
select is(manager_workspace()->'incidents'->0->'requirements'->0->>'template_id', 'c6000000-0000-4000-8000-000000000001', 'Incident detail includes its scoped verification requirements');
select throws_ok($$select transition_incident('c7300000-0000-4000-8000-000000000001', 'verification_pending', 4, '{"controls_reviewed":true,"notice_reviewed":true,"notice_ref":"simulation://notice"}', 'Request early')$$, '22023', null, 'A saved plan does not replace accepted work evidence');
select is(manager_workspace()->'incidents'->0->>'version', '4', 'Failed verification retains the separately saved plan version');
select throws_ok($$select transition_work_order('c7400000-0000-4000-8000-000000000001', 'in_progress', 2, '{}', 'Impersonate worker')$$, '42501', null, 'Manager cannot perform an assigned worker action');

reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select lives_ok($$
 select transition_work_order('c7400000-0000-4000-8000-000000000001', 'in_progress', 2, '{}', 'Begin assigned work');
 select transition_work_order('c7400000-0000-4000-8000-000000000001', 'completed', 3, '{"completion_evidence":"simulation://cover-repair"}', 'Record completion');
$$, 'Actual assignee records completion through existing commands');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000003","role":"authenticated"}';
set local role authenticated;
select is(transition_work_order('c7400000-0000-4000-8000-000000000001', 'accepted', 4, '{}', 'Review recorded work'), 5, 'Manager accepts completion evidence');
select is(manager_workspace()->'incidents'->0->>'state', 'mitigation', 'Accepted work does not close or advance the incident');
select is(transition_incident('c7300000-0000-4000-8000-000000000001', 'verification_pending', 4, '{"controls_reviewed":true,"notice_reviewed":true,"notice_ref":"simulation://reviewed-notice"}', 'Request post-action verification'), 5, 'Verification transition uses the saved plan version');
select throws_ok($$select transition_incident('c7300000-0000-4000-8000-000000000001', 'resolved', 5, '{"communication_ref":"simulation://notice"}', 'No new verification')$$, '22023', null, 'Original risk inspection cannot satisfy post-action verification');
select is(escalate_incident('c7300000-0000-4000-8000-000000000001', 5, 'Critical concern remains open'), 6, 'Critical incident can be escalated internally');
select is(manager_workspace()->'incidents'->0->>'state', 'verification_pending', 'Internal escalation retains the outstanding verification state');
select throws_ok($$select revoke_public_record('c5000000000040008000000000000001', ' ')$$, '22023', null, 'QR revocation requires a reason');
select lives_ok($$select revoke_public_record('c5000000000040008000000000000001', 'Damaged printed code')$$, 'Manager can revoke a scoped QR identity');
select is(manager_workspace()->'qrs'->0->>'point_id', 'c5000000-0000-4000-8000-000000000001', 'Revocation preserves the original point identity');
select is((manager_workspace()->'qrs'->0->>'revoked_at')::timestamptz, '2026-11-10T12:00:00Z'::timestamptz, 'Revocation is a dated simulation event');
select lives_ok($$select revoke_public_record('c5000000000040008000000000000001', 'Lost response retry')$$, 'Acknowledgement loss can safely retry QR revocation');
select is((select count(*)::int from audit_events where aggregate_id = 'c5000000000040008000000000000001' and new_state = 'revoked'), 1, 'Revocation retry does not duplicate its audit');

reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000004","role":"authenticated"}';
set local role authenticated;
select is(jsonb_array_length(manager_workspace()->'facilities'), 3, 'Organization admin can select all and only its tenant facilities');
select is(manager_workspace('c2000000-0000-4000-8000-000000000004')->'systems', '[]'::jsonb, 'Authorized empty facility returns empty record arrays');
select is(manager_workspace('c2000000-0000-4000-8000-000000000004')->'records', '[]'::jsonb, 'Authorized empty facility has no fabricated samples or results');
select throws_ok($$select manager_workspace('c2000000-0000-4000-8000-000000000003')$$, '42501', null, 'Organization admin cannot cross the tenant boundary');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000011","role":"authenticated"}';
set local role authenticated;
select is(jsonb_array_length(manager_workspace()->'facilities'), 1, 'Facility-scoped administrator is not an organization-wide administrator');
select throws_ok($$select manager_workspace('c2000000-0000-4000-8000-000000000002')$$, '42501', null, 'Facility administrator cannot open its sibling');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000009","role":"authenticated"}';
set local role authenticated;
select is(jsonb_array_length(manager_workspace()->'facilities'), 2, 'Multi-facility manager sees exactly its two assignments');
select is(manager_workspace('c2000000-0000-4000-8000-000000000002')->'samples'->0->>'id', 'c7000000-0000-4000-8000-000000000002', 'Scope switch returns the newly selected facility records');
select is(jsonb_array_length(manager_workspace('c2000000-0000-4000-8000-000000000002')->'memberships'), 4, 'Scope switch does not retain the previous private roster');
reset role;
update memberships set status = 'revoked' where user_id = 'c9000000-0000-4000-8000-000000000009' and facility_id = 'c2000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select manager_workspace('c2000000-0000-4000-8000-000000000001')$$, '42501', null, 'Existing session loses a revoked facility immediately');
select throws_ok($$select revoke_public_record('c5000000000040008000000000000001', 'Retry after revocation')$$, '42501', null, 'Even an idempotent command rechecks current membership');
select is(jsonb_array_length(manager_workspace()->'facilities'), 1, 'Other active assignment remains available after scoped revocation');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000013","role":"authenticated"}';
set local role authenticated;
select lives_ok($$select manager_workspace()$$, 'Future actual membership expiry is independent of the simulation clock');

reset role;
select * from finish();
rollback;
