-- Full laboratory commands under the same roles and JWT claims used by
-- PostgREST. Fixture data and every mutation are rolled back after the suite.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into organizations(id, name, settings, is_simulated) values
 ('b1000000-0000-4000-8000-000000000001', 'Lab test A', '{"simulation_clock":"2026-11-10T12:00:00Z","simulation_seed":20261101,"model_version":1}', true),
 ('b1000000-0000-4000-8000-000000000002', 'Lab test B', '{"simulation_clock":"2026-11-10T12:00:00Z"}', true),
 ('b1000000-0000-4000-8000-000000000003', 'Non-simulation contract fixture', '{}', false);
insert into facilities(id, organization_id, public_label, is_simulated) values
 ('b2000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'Assigned lab facility', true),
 ('b2000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', 'Sibling facility', true),
 ('b2000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000002', 'Other tenant', true),
 ('b2000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000003', 'Non-simulation fixture', false);
insert into auth.users(id, email)
 select ('b9000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
   'lab-contract-' || n || '@tankloop.invalid' from generate_series(1, 10) n;
insert into memberships(user_id, organization_id, facility_id, role, status, valid_until, is_simulated) values
 ('b9000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'field', 'active', null, true),
 ('b9000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'lab', 'active', null, true),
 ('b9000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'manager', 'active', null, true),
 ('b9000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000001', null, 'admin', 'active', null, true),
 ('b9000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000002', 'lab', 'active', null, true),
 ('b9000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000003', 'lab', 'active', null, true),
 ('b9000000-0000-4000-8000-000000000007', 'b1000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'lab', 'revoked', null, true),
 ('b9000000-0000-4000-8000-000000000008', 'b1000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'lab', 'active', now() - interval '1 day', true),
 ('b9000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'lab', 'active', null, true),
 ('b9000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000002', 'lab', 'active', null, true),
 ('b9000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000004', 'field', 'active', null, false),
 ('b9000000-0000-4000-8000-000000000010', 'b1000000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000004', 'lab', 'active', null, false);
insert into water_systems(id, organization_id, facility_id, label, is_simulated)
 select replace(id::text, 'b2000000', 'b3000000')::uuid, organization_id, id, 'Test network', is_simulated
 from facilities where id::text like 'b2000000-%';
insert into assets(id, organization_id, facility_id, system_id, type, label, is_simulated)
 select replace(id::text, 'b3000000', 'b4000000')::uuid, organization_id, facility_id, id, 'tank', 'Test tank', is_simulated
 from water_systems where id::text like 'b3000000-%';
insert into sampling_points(id, organization_id, facility_id, asset_id, label, is_simulated)
 select replace(id::text, 'b4000000', 'b5000000')::uuid, organization_id, facility_id, id, 'Test outlet', is_simulated
 from assets where id::text like 'b4000000-%';

-- A late receipt-storage failure must roll back the entire intake transaction.
alter table command_receipts add constraint lab_test_receipt_failure
 check (client_event_id <> 'b0000000-0000-4000-8000-000000000099') not valid;

set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select lives_ok($$select set_config('lab.accept', register_sample('b5000000-0000-4000-8000-000000000001', '2026-11-10T10:00:00Z', 'Membrane filtration', 'Simulated sealed transport', 'b8000000-0000-4000-8000-000000000001')::text, true)$$, 'Field registers the intake sample through its existing RPC');
select lives_ok($$select set_config('lab.reject', register_sample('b5000000-0000-4000-8000-000000000001', '2026-11-10T12:00:00Z', 'Membrane filtration', 'Simulated transport deviation', 'b8000000-0000-4000-8000-000000000002')::text, true)$$, 'Field registers a same-point follow-up sample');
select lives_ok($$select set_config('lab.rollback', register_sample('b5000000-0000-4000-8000-000000000001', '2026-11-10T10:00:00Z', 'Membrane filtration', 'Simulated transport', 'b8000000-0000-4000-8000-000000000003')::text, true)$$, 'Register sample for transaction rollback check');
select lives_ok($$select set_config('lab.presence', register_sample('b5000000-0000-4000-8000-000000000001', '2026-11-10T10:00:00Z', 'H2S screen', 'Simulated transport', 'b8000000-0000-4000-8000-000000000004')::text, true)$$, 'Register a separate screening method');
select lives_ok($$select set_config('lab.real', register_sample('b5000000-0000-4000-8000-000000000004', now() - interval '1 hour', 'Membrane filtration', 'Contract fixture, no physical water test', 'b8000000-0000-4000-8000-000000000005')::text, true)$$, 'Register non-simulation contract fixture');
select throws_ok($$select lab_workspace()$$, '42501', null, 'Field membership cannot open the specialist lab projection');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'accept', '{"custody_note":"Handoff"}', 'Accept')$$, '42501', null, 'Field membership cannot record lab intake');
select throws_ok($$update test_results set state = 'reviewed', reviewed_by = auth.uid()$$, '42501', null, 'Direct result attestation is not a client privilege');

reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000003","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select lab_workspace()$$, '42501', null, 'Manager membership is not a lab reviewer assignment');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'attest', '{"report_ref":"https://reports.example/test"}', 'Attest')$$, '42501', null, 'A manager cannot attest using the lab command');
reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000004","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select lab_workspace()$$, '42501', null, 'Organization administration does not imply reviewer authority');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'correct', '{}', 'Correct')$$, '42501', null, 'An administrator cannot impersonate a laboratory reviewer');
reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000005","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from test_results), 0, 'Sibling-facility reviewer cannot read these results through RLS');
select throws_ok($$select lab_workspace('b2000000-0000-4000-8000-000000000001')$$, '42501', null, 'Known facility ID cannot bypass the assignment');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'accept', '{"custody_note":"Handoff"}', 'Accept')$$, '42501', null, 'Same-tenant sibling lab cannot mutate a known result');
reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000006","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from samples), 0, 'Other-tenant reviewer cannot enumerate samples');
select throws_ok($$select lab_workspace('b2000000-0000-4000-8000-000000000001')$$, '42501', null, 'Lab projection enforces the tenant boundary');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'attest', '{"report_ref":"https://reports.example/test"}', 'Review')$$, '42501', null, 'Lab commands enforce the tenant boundary');
reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000007","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from test_results), 0, 'Revoked reviewer loses RLS reads');
select throws_ok($$select lab_workspace()$$, '42501', null, 'Revoked reviewer loses the lab snapshot');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'accept', '{}', 'Accept')$$, '42501', null, 'Revoked reviewer cannot submit a queued decision');
reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000008","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from test_results), 0, 'Expired reviewer loses RLS reads using actual server time');
select throws_ok($$select lab_workspace()$$, '42501', null, 'The simulated future clock cannot extend expired access');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'attest', '{}', 'Review')$$, '42501', null, 'Expired reviewer cannot attest');
reset role;
set local request.jwt.claims = '{"role":"anon"}';
set local role anon;
select throws_ok($$select lab_workspace()$$, '42501', null, 'Anonymous lab snapshot is denied');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'accept', '{}', 'Accept')$$, '42501', null, 'Anonymous lab command is denied');

reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select is(lab_workspace()->'facility'->>'id', 'b2000000-0000-4000-8000-000000000001', 'Default snapshot chooses an assigned facility');
select is(jsonb_array_length(lab_workspace()->'facilities'), 1, 'Facility picker contains only reviewer assignments');
select is(lab_workspace()->>'actor_id', auth.uid()::text, 'Snapshot derives reviewer identity from the session');
select is((lab_workspace()->>'as_of')::timestamptz, '2026-11-10T12:00:00Z'::timestamptz, 'Lab shares the canonical simulation clock');
select is((lab_workspace()->>'fetched_at')::timestamptz, statement_timestamp(), 'Freshness uses actual read time, separate from sample time');
select is(lab_workspace()->'simulation'->>'simulation_seed', '20261101', 'Simulation seed is available for disclosure');
select is(jsonb_array_length(lab_workspace()->'records'), 4, 'Snapshot contains only results from this facility');
select is((select r->'sample'->>'preservation_note' from jsonb_array_elements(lab_workspace()->'records') r where r->>'id' = current_setting('lab.accept')), 'Simulated sealed transport', 'Snapshot includes sample transport evidence');
select throws_ok($$select lab_command(null, current_setting('lab.accept')::uuid, 0, 'accept', '{}', 'Accept')$$, '22023', null, 'A durable command event ID is required');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'accept', '[]', 'Accept')$$, '22023', null, 'Payload must be an object');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'accept', '{"custody_note":"Handoff"}', ' ')$$, '22023', null, 'Intake requires a nonblank reason');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'accept', '{}', 'Accept')$$, '22023', null, 'First receipt requires a custody handoff note');
select throws_ok($$select lab_command('b0000000-0000-4000-8000-000000000099', current_setting('lab.rollback')::uuid, 0, 'accept', '{"custody_note":"Handoff"}', 'Accept')$$, '23514', null, 'A late receipt-storage failure rolls back intake');
select is((select state::text from test_results where id = current_setting('lab.rollback')::uuid), 'collected', 'Failed intake did not partially accept the sample');
select is((select count(*)::int from custody_events where sample_id = 'b8000000-0000-4000-8000-000000000003'), 0, 'Failed intake did not leave a custody event');
select is((select count(*)::int from audit_events where aggregate_id = current_setting('lab.rollback')), 1, 'Failed intake did not leave receipt or validity audit');
select lives_ok($$select set_config('lab.accept_receipt', lab_command('b0000000-0000-4000-8000-000000000001', current_setting('lab.accept')::uuid, 0, 'accept', '{"custody_note":"Seal and handoff checked"}', 'Transport accepted')::text, true)$$, 'Authorized reviewer atomically receives and accepts a sample');
select is(current_setting('lab.accept_receipt')::jsonb->>'state', 'valid', 'Server receipt confirms accepted-for-testing stage');
select is(current_setting('lab.accept_receipt')::jsonb->>'version', '2', 'Atomic intake includes both lifecycle steps');
select is(current_setting('lab.accept_receipt')::jsonb->>'actor_id', auth.uid()::text, 'Receipt actor is server-derived');
select is(current_setting('lab.accept_receipt')::jsonb->>'is_simulated', 'true', 'Server acknowledgement retains simulation disclosure');
select is((select note from custody_events where sample_id = 'b8000000-0000-4000-8000-000000000001'), 'Seal and handoff checked', 'Physical handoff note is retained');
select is((select from_actor::text from custody_events where sample_id = 'b8000000-0000-4000-8000-000000000001'), 'b9000000-0000-4000-8000-000000000001', 'Custody starts at the actual collector');
select is((select to_actor from custody_events where sample_id = 'b8000000-0000-4000-8000-000000000001'), auth.uid(), 'Custody ends at the authenticated reviewer');
select is(lab_command('b0000000-0000-4000-8000-000000000001', current_setting('lab.accept')::uuid, 0, 'accept', '{"custody_note":"Seal and handoff checked"}', 'Transport accepted'), current_setting('lab.accept_receipt')::jsonb, 'Lost intake acknowledgement retries the exact receipt');
select is((select count(*)::int from audit_events where aggregate_id = current_setting('lab.accept')), 3, 'Intake retry does not duplicate custody or validity audit');
select throws_ok($$select lab_command('b0000000-0000-4000-8000-000000000001', current_setting('lab.accept')::uuid, 0, 'accept', '{"custody_note":"Changed"}', 'Transport accepted')$$, '23505', null, 'An event ID cannot be reused for changed content');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 0, 'reject', '{}', 'Stale view')$$, '40001', null, 'A stale decision cannot overwrite accepted intake');

select lives_ok($$select lab_command('b0000000-0000-4000-8000-000000000002', current_setting('lab.reject')::uuid, 0, 'reject', '{"custody_note":"Holding-time deviation recorded"}', 'Holding time exceeded')$$, 'Reviewer can reject intake with a retained reason');
select is((select rejection_reason from test_results where id = current_setting('lab.reject')::uuid), 'Holding time exceeded', 'Rejection reason is retained');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.reject')::uuid, 2, 'enter_result', '{"indicator":"e_coli","method":"Membrane filtration","value":0,"units":"cfu_per100ml","detection_limit":1}', 'Attempt negative')$$, '22023', null, 'Rejected samples cannot become negative test evidence');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.reject')::uuid, 2, 'attest', '{"report_ref":"simulation://rejected"}', 'Attempt review')$$, '22023', null, 'Rejected samples cannot be attested');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.reject')::uuid, 2, 'correct', '{"value":0,"detection_limit":1,"report_ref":"simulation://rejected"}', 'Attempt revision')$$, '22023', null, 'A correction cannot turn rejection into verified evidence');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 2, 'enter_result', '{"indicator":"e_coli","method":"Other method","value":0,"units":"cfu_per100ml","detection_limit":1}', 'Wrong method')$$, '22023', null, 'Entry preserves the planned method');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 2, 'enter_result', '{"indicator":"e_coli","method":"Membrane filtration","value":-1,"units":"cfu_per100ml","detection_limit":1}', 'Invalid count')$$, '23514', null, 'Negative counts are rejected by the database');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 2, 'enter_result', '{"indicator":"e_coli","method":"Membrane filtration","value":0,"units":"cfu_per100ml","detection_limit":0}', 'Invalid limit')$$, '23514', null, 'Detection limits must be positive');
select lives_ok($$select lab_command('b0000000-0000-4000-8000-000000000003', current_setting('lab.accept')::uuid, 2, 'enter_result', '{"indicator":"e_coli","method":"Membrane filtration","value":7.25,"units":"mpn_per100ml","detection_limit":0.5}', 'Simulated reported measurement')$$, 'MPN entry preserves fractional values and detection limits');
select is((select value from test_results where id = current_setting('lab.accept')::uuid), 7.25::numeric, 'Reported MPN value is not rounded');
select is((select detection_limit from test_results where id = current_setting('lab.accept')::uuid), 0.5::numeric, 'Reported detection limit is not normalized');
select is((select reviewed_by from test_results where id = current_setting('lab.accept')::uuid), null::uuid, 'Result entry alone has no reviewer');
select is((select count(*)::int from incidents where source_id = current_setting('lab.accept')::uuid), 0, 'Unreviewed entry cannot create a confirmed laboratory incident');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 3, 'attest', '{}', 'Review')$$, '22023', null, 'A report is required for attestation');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 3, 'attest', '{"report_ref":"http://reports.example/report"}', 'Review')$$, '22023', null, 'Report references require HTTPS');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 3, 'attest', '{"report_ref":"javascript:alert(1)"}', 'Review')$$, '22023', null, 'Script references cannot be signed-report evidence');
select lives_ok($$select set_config('lab.attest_receipt', lab_command('b0000000-0000-4000-8000-000000000004', current_setting('lab.accept')::uuid, 3, 'attest', '{"report_ref":"https://reports.example/signed/original","reviewed_by":"b9000000-0000-4000-8000-000000000009"}', 'Reviewed method, identity and report')::text, true)$$, 'Scoped laboratory reviewer attests linked evidence');
select is((select reviewed_by from test_results where id = current_setting('lab.accept')::uuid), auth.uid(), 'A payload cannot impersonate a different reviewer');
select is((select reviewed_at from test_results where id = current_setting('lab.accept')::uuid), '2026-11-10T12:00:00Z'::timestamptz, 'Review timestamp comes from the server');
select is((select state::text from test_results where id = current_setting('lab.accept')::uuid), 'reviewed', 'Attestation does not automatically publish');
select is((select count(*)::int from incidents where source_id = current_setting('lab.accept')::uuid), 1, 'Reviewed finding opens a separate accountable incident');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 4, 'publish', '{}', 'Publish')$$, '22023', null, 'Lab command exposes no publication action');
select lives_ok($$select set_config('lab.incident', (select id::text from incidents where source_id = current_setting('lab.accept')::uuid), true)$$, 'Retain the finding for the verification journey');

-- The rejection cannot satisfy a real verification attempt after accepted work.
reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000003","role":"authenticated"}';
set local role authenticated;
select lives_ok($$
 select transition_result(current_setting('lab.accept')::uuid, 'published', 4, '{}', 'Publish the dated result');
 select transition_incident(current_setting('lab.incident')::uuid, 'triaged', 0, '{"priority":"urgent","uncertainty":"Single point, scope limited"}', 'Triage');
 select transition_incident(current_setting('lab.incident')::uuid, 'assigned', 1, '{"owner_id":"b9000000-0000-4000-8000-000000000001","due_at":"2026-11-11T12:00:00Z","required_response":"Inspect fittings"}', 'Assign');
 select propose_work_order('b7000000-0000-4000-8000-000000000001', current_setting('lab.incident')::uuid, 'Inspect fittings');
 select transition_work_order('b7000000-0000-4000-8000-000000000001', 'approval_pending', 0, '{}', 'Request approval');
 select transition_work_order('b7000000-0000-4000-8000-000000000001', 'assigned', 1, '{"assignee_id":"b9000000-0000-4000-8000-000000000001","due_at":"2026-11-11T12:00:00Z"}', 'Approve');
 select transition_incident(current_setting('lab.incident')::uuid, 'mitigation', 2, '{}', 'Authorized work');
 select set_verification_plan(current_setting('lab.incident')::uuid, 3, '[{"kind":"sample","point_id":"b5000000-0000-4000-8000-000000000001","indicator":"e_coli","method":"Membrane filtration"}]', 'Require same-point follow-up');
$$, 'Manager configures approved work and scope-specific sample verification');
reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select lives_ok($$
 select transition_work_order('b7000000-0000-4000-8000-000000000001', 'in_progress', 2, '{}', 'Begin');
 select transition_work_order('b7000000-0000-4000-8000-000000000001', 'completed', 3, '{"completion_evidence":"simulation://work/repair"}', 'Record repair');
$$, 'Assigned worker records completion evidence');
reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000003","role":"authenticated"}';
set local role authenticated;
select lives_ok($$
 select transition_work_order('b7000000-0000-4000-8000-000000000001', 'accepted', 4, '{}', 'Accept work');
 select transition_incident(current_setting('lab.incident')::uuid, 'verification_pending', 4, '{"controls_reviewed":true,"notice_reviewed":true,"notice_ref":"simulation://notice"}', 'Review controls and notice');
$$, 'Manager accepts work while retaining pending verification');
select throws_ok($$select transition_incident(current_setting('lab.incident')::uuid, 'resolved', 5, '{"communication_ref":"simulation://closure"}', 'Attempt closure with rejected follow-up')$$, '22023', null, 'Rejected follow-up cannot satisfy the verification requirement');
select is((select state::text from incidents where id = current_setting('lab.incident')::uuid), 'verification_pending', 'Rejected follow-up leaves the concern open');

-- A second authorized reviewer creates immutable, separately attested revisions.
reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000009","role":"authenticated"}';
set local role authenticated;
select is(jsonb_array_length(lab_workspace()->'facilities'), 2, 'A multi-facility reviewer sees precisely their two assignments');
select lives_ok($$select set_config('lab.original', (select to_jsonb(r)::text from test_results r where id = current_setting('lab.accept')::uuid), true)$$, 'Capture the complete published original before correction');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 5, 'correct', '{"value":0,"detection_limit":0.25,"report_ref":"https://reports.example/corrected"}', '')$$, '22023', null, 'Correction requires a reason');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 5, 'correct', '{"value":0,"report_ref":"https://reports.example/corrected"}', 'Correction')$$, '22023', null, 'Correction retains an explicit detection limit');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.accept')::uuid, 5, 'correct', '{"value":-1,"detection_limit":0.25,"report_ref":"https://reports.example/corrected"}', 'Invalid correction')$$, '23514', null, 'Invalid revision rolls back after attempting to supersede the original');
select is((select to_jsonb(r) from test_results r where id = current_setting('lab.accept')::uuid), current_setting('lab.original')::jsonb, 'A failed correction leaves the entire original unchanged');
select lives_ok($$select set_config('lab.correction_receipt', lab_command('b0000000-0000-4000-8000-000000000005', current_setting('lab.accept')::uuid, 5, 'correct', '{"value":0,"detection_limit":0.25,"report_ref":"https://reports.example/corrected","method":"Ignored scope spoof"}', 'Transcription correction')::text, true)$$, 'Authorized reviewer creates a superseding revision');
select lives_ok($$select set_config('lab.revision', current_setting('lab.correction_receipt')::jsonb->>'result_id', true)$$, 'Retain the new revision identifier');
select isnt(current_setting('lab.revision'), current_setting('lab.accept'), 'Correction has a new immutable result ID');
select is((select state::text from test_results where id = current_setting('lab.accept')::uuid), 'superseded', 'Earlier result becomes explicitly historical');
select is((select to_jsonb(r) - array['state','version'] from test_results r where id = current_setting('lab.accept')::uuid), current_setting('lab.original')::jsonb - array['state','version'], 'Original value, method, units, report, actor and all timestamps are preserved');
select is((select revision_of::text from test_results where id = current_setting('lab.revision')::uuid), current_setting('lab.accept'), 'Revision links to the earlier result');
select is((select correction_reason from test_results where id = current_setting('lab.revision')::uuid), 'Transcription correction', 'Correction reason is immutable provenance');
select is((select corrected_by from test_results where id = current_setting('lab.revision')::uuid), auth.uid(), 'Correction records its own authorized actor');
select is((select corrected_at from test_results where id = current_setting('lab.revision')::uuid), '2026-11-10T12:00:00Z'::timestamptz, 'Correction records the canonical server timestamp');
select is((select method from test_results where id = current_setting('lab.revision')::uuid), 'Membrane filtration', 'Correction cannot change the method via extra payload fields');
select is((select units from test_results where id = current_setting('lab.revision')::uuid), 'mpn_per100ml', 'Correction retains the original units');
select is((select detection_limit from test_results where id = current_setting('lab.revision')::uuid), 0.25::numeric, 'Corrected detection limit is recorded without changing scope');
select is((select published_at from test_results where id = current_setting('lab.revision')::uuid), null::timestamptz, 'Correction needs its own separate publication decision');
select is(lab_command('b0000000-0000-4000-8000-000000000005', current_setting('lab.accept')::uuid, 5, 'correct', '{"value":0,"detection_limit":0.25,"report_ref":"https://reports.example/corrected","method":"Ignored scope spoof"}', 'Transcription correction'), current_setting('lab.correction_receipt')::jsonb, 'Lost correction acknowledgement returns the exact original receipt');
select is((select count(*)::int from test_results where sample_id = 'b8000000-0000-4000-8000-000000000001'), 2, 'Correction retry does not fork the lineage');
select is((select count(*)::int from audit_events where aggregate_id = current_setting('lab.accept') and new_state = 'superseded'), 1, 'Superseding audit is written once');
select is((select r->>'report_ref' from jsonb_array_elements(lab_workspace('b2000000-0000-4000-8000-000000000001')->'records') r where r->>'id' = current_setting('lab.accept')), 'https://reports.example/signed/original', 'Lab snapshot still exposes the preserved original report');
select throws_ok($$update test_results set value = 0 where id = current_setting('lab.accept')::uuid$$, '42501', null, 'A reviewer cannot overwrite historical evidence directly');
select throws_ok($$delete from custody_events$$, '42501', null, 'A reviewer cannot erase chain of custody');

-- Presence/absence and screening cannot be silently treated as colony counts.
select lives_ok($$select lab_command(gen_random_uuid(), current_setting('lab.presence')::uuid, 0, 'accept', '{"custody_note":"Simulated screening handoff"}', 'Accept screen sample')$$, 'Screening sample completes intake');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.presence')::uuid, 2, 'enter_result', '{"indicator":"hydrogen_sulfide","method":"H2S screen","value":1,"units":"cfu_per100ml","detection_limit":1}', 'Wrong units')$$, '23514', null, 'H2S cannot be reported in E. coli count units');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.presence')::uuid, 2, 'enter_result', '{"indicator":"hydrogen_sulfide","method":"H2S screen","value":2,"units":"presence_absence","detection_limit":1}', 'Wrong presence value')$$, '23514', null, 'Presence/absence accepts only zero or one');
select lives_ok($$select lab_command(gen_random_uuid(), current_setting('lab.presence')::uuid, 2, 'enter_result', '{"indicator":"hydrogen_sulfide","method":"H2S screen","value":1,"units":"presence_absence","detection_limit":1}', 'Simulated positive screen')$$, 'Presence/absence preserves exact screening indicator and limit');
select lives_ok($$select lab_command(gen_random_uuid(), current_setting('lab.presence')::uuid, 3, 'attest', '{"report_ref":"simulation://reports/screen"}', 'Review synthetic screen')$$, 'Simulation report references are accepted for simulated samples');
select is((select count(*)::int from incidents where source_id = current_setting('lab.presence')::uuid), 0, 'H2S review does not become an E. coli confirmed finding');

reset role;
update memberships set status = 'revoked' where user_id = 'b9000000-0000-4000-8000-000000000009';
set local role authenticated;
select throws_ok($$select lab_command('b0000000-0000-4000-8000-000000000005', current_setting('lab.accept')::uuid, 5, 'correct', '{"value":0,"detection_limit":0.25,"report_ref":"https://reports.example/corrected","method":"Ignored scope spoof"}', 'Transcription correction')$$, '42501', null, 'Revocation is rechecked even when replaying an existing receipt');
select throws_ok($$select lab_workspace()$$, '42501', null, 'Revoked multi-facility reviewer loses every lab projection');
reset role;
set local request.jwt.claims = '{"sub":"b9000000-0000-4000-8000-000000000010","role":"authenticated"}';
set local role authenticated;
select lives_ok($$
 select lab_command(gen_random_uuid(), current_setting('lab.real')::uuid, 0, 'accept', '{"custody_note":"Contract fixture handoff"}', 'Contract test');
 select lab_command(gen_random_uuid(), current_setting('lab.real')::uuid, 2, 'enter_result', '{"indicator":"e_coli","method":"Membrane filtration","value":0,"units":"cfu_per100ml","detection_limit":1}', 'Contract test');
$$, 'CFU/100 mL is supported in the non-simulation contract');
select throws_ok($$select lab_command(gen_random_uuid(), current_setting('lab.real')::uuid, 3, 'attest', '{"report_ref":"simulation://fake-report"}', 'Attempt simulation reference')$$, '22023', null, 'A real record cannot use a simulation report reference');
select lives_ok($$select lab_command(gen_random_uuid(), current_setting('lab.real')::uuid, 3, 'attest', '{"report_ref":"https://reports.example/contract-fixture"}', 'Contract test')$$, 'Non-simulation attestation requires an HTTPS signed-report reference');
select is((select is_simulated from test_results where id = current_setting('lab.real')::uuid), false, 'Lab command cannot change facility simulation provenance');

reset role;
select * from finish();
rollback;
