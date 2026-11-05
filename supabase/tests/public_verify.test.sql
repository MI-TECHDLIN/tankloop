-- Exercise the anonymous QR journey through real RPCs and database roles.
-- These synthetic fixtures and mutations are rolled back after the suite.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into organizations(id, name, settings, is_simulated) values
 ('c1000000-0000-4000-8000-000000000001', 'Public contract A', '{"simulation_clock":"2026-11-10T12:00:00Z"}', true),
 ('c1000000-0000-4000-8000-000000000002', 'Public contract B', '{"simulation_clock":"2026-11-10T12:00:00Z"}', true),
 ('c1000000-0000-4000-8000-000000000003', 'Non-simulation contract fixture', '{}', false);
insert into facilities(id, organization_id, public_label, is_simulated) values
 ('c2000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'Public test facility', true),
 ('c2000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001', 'Sibling facility', true),
 ('c2000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000002', 'Other tenant', true),
 ('c2000000-0000-4000-8000-000000000004', 'c1000000-0000-4000-8000-000000000003', 'Non-simulation fixture', false);
insert into water_systems(id, organization_id, facility_id, label, is_simulated)
 select replace(id::text, 'c2000000', 'c3000000')::uuid, organization_id, id, 'Contract network', is_simulated
 from facilities where id::text like 'c2000000-%';
insert into assets(id, organization_id, facility_id, system_id, type, label, is_simulated)
 select replace(id::text, 'c3000000', 'c4000000')::uuid, organization_id, facility_id, id, 'tank', 'Contract tank', is_simulated
 from water_systems where id::text like 'c3000000-%';
insert into sampling_points(id, organization_id, facility_id, asset_id, label, is_simulated)
 select replace(id::text, 'c4000000', 'c5000000')::uuid, organization_id, facility_id, id, 'Contract outlet', is_simulated
 from assets where id::text like 'c4000000-%';
insert into sampling_points(id, organization_id, facility_id, asset_id, label, is_simulated) values
 ('c5000000-0000-4000-8000-000000000005', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'c4000000-0000-4000-8000-000000000001', 'Other point in this facility', true);
insert into public_records(organization_id, facility_id, point_id, token, issued_at, is_simulated)
 select organization_id, facility_id, id, repeat('a' || right(id::text, 1), 16), '2026-11-01T00:00:00Z', is_simulated
 from sampling_points where id::text like 'c5000000-%';
insert into public_records(organization_id, facility_id, point_id, token, issued_at, is_simulated) values
 ('c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000001', repeat('a6', 16), '2026-11-01T00:00:00Z', true);
insert into auth.users(id, email)
 select ('c9000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, 'public-contract-' || n || '@tankloop.invalid'
 from generate_series(1, 8) n;
insert into memberships(user_id, organization_id, facility_id, role, status, valid_until, is_simulated) values
 ('c9000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'manager', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'lab', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'field', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000004', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000002', 'manager', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000005', 'c1000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000003', 'manager', 'active', null, true),
 ('c9000000-0000-4000-8000-000000000006', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'manager', 'revoked', null, true),
 ('c9000000-0000-4000-8000-000000000007', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'manager', 'active', now() - interval '1 day', true),
 ('c9000000-0000-4000-8000-000000000008', 'c1000000-0000-4000-8000-000000000001', null, 'admin', 'active', null, true);

-- If audit persistence fails, neither private input nor an incident may survive.
alter table audit_events add constraint public_concern_test_failure
 check (organization_id <> 'c1000000-0000-4000-8000-000000000001') not valid;
set local request.jwt.claims = '{"role":"anon"}';
set local role anon;
select is(lookup_public_point(null), '{"status":"missing"}'::jsonb, 'Null QR makes no water-quality claim');
select is(lookup_public_point('point-1'), '{"status":"missing"}'::jsonb, 'Sequential point IDs are not public tokens');
select is(lookup_public_point(repeat('ff', 16)), '{"status":"missing"}'::jsonb, 'Unknown opaque token returns only missing');
select is(lookup_public_record(repeat('ff', 16)), null::jsonb, 'Existing lookup preserves its unavailable contract');
select is(lookup_public_point(repeat('a1', 16))->>'status', 'found', 'Active printed token loads without a session');
select is(lookup_public_point(repeat('a1', 16))->'record'->>'wording', 'We do not have a current verified test record for this point.', 'No test means no current verified record');
select is(lookup_public_point(repeat('a1', 16))->>'has_unreviewed_results', 'false', 'No pending records are invented');
select throws_ok($$select * from public_records$$, '42501', null, 'Anonymous scans cannot enumerate QR labels');
select throws_ok($$select * from public_concerns$$, '42501', null, 'Anonymous scans cannot read private reports');
select throws_ok($$insert into public_concerns(client_event_id) values(gen_random_uuid())$$, '42501', null, 'Direct anonymous table writes cannot bypass RPC guards');
select throws_ok($$select submit_public_concern(null, repeat('a1',16), 'smell', 'Simulated smell')$$, '22023', null, 'A receipt identity is required');
select throws_ok($$select submit_public_concern(gen_random_uuid(), 'point-1', 'smell', 'Simulated smell')$$, '22023', null, 'Input requires an opaque token');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'laboratory', 'Simulated smell')$$, '22023', null, 'A reporter cannot claim laboratory provenance');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'smell', '    ')$$, '22023', null, 'Blank descriptions are rejected');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'smell', 'Concern' || repeat(' ', 2000))$$, '22023', null, 'Whitespace cannot bypass the description size bound');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'smell', 'Simulated smell', 'private@example.invalid', false)$$, '22023', null, 'Contact details require explicit consent');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'smell', 'Simulated smell', null, true)$$, '22023', null, 'Consent without contact details is rejected');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'smell', 'Simulated smell', '  ', true)$$, '22023', null, 'Blank contact details are rejected');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'smell', 'Simulated smell', 'name' || repeat(' ',320), true)$$, '22023', null, 'Whitespace cannot bypass the contact size bound');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'smell', 'Simulated rollback exercise')$$, '23514', null, 'Audit failure rolls back the entire anonymous submission');
reset role;
select is((select count(*)::int from public_concerns where organization_id = 'c1000000-0000-4000-8000-000000000001'), 0, 'Failed audit leaves no private input');
select is((select count(*)::int from incidents where organization_id = 'c1000000-0000-4000-8000-000000000001'), 0, 'Failed audit leaves no incident');
alter table audit_events drop constraint public_concern_test_failure;
set local role anon;
select lives_ok($$select set_config('verify.receipt', submit_public_concern('c0000000-0000-4000-8000-000000000001', repeat('a1',16), 'mismatch', 'PRIVATE simulated label mismatch', 'private@example.invalid', true)::text, true)$$, 'Anonymous resident submits private concern with optional contact');
select is(current_setting('verify.receipt')::jsonb->>'event_id', 'c0000000-0000-4000-8000-000000000001', 'Receipt echoes only the caller event identity');
select is((current_setting('verify.receipt')::jsonb->>'received_at')::timestamptz, '2026-11-10T12:00:00Z'::timestamptz, 'Receipt uses the server-owned exercise clock');
select is(current_setting('verify.receipt')::jsonb->>'is_simulated', 'true', 'Database receipt retains simulation disclosure');
select is(current_setting('verify.receipt')::jsonb - array['event_id','received_at','is_simulated'], '{}'::jsonb, 'Receipt contains no internal record, tenant or contact identifiers');
select is(submit_public_concern('c0000000-0000-4000-8000-000000000001', repeat('a1',16), 'mismatch', 'PRIVATE simulated label mismatch', 'private@example.invalid', true), current_setting('verify.receipt')::jsonb, 'Lost acknowledgement replays the original receipt');
select throws_ok($$select submit_public_concern('c0000000-0000-4000-8000-000000000001', repeat('a1',16), 'smell', 'Changed private content')$$, '23505', null, 'Event identity cannot be reused for changed content');
select throws_ok($$select submit_public_concern('c0000000-0000-4000-8000-000000000001', repeat('a3',16), 'mismatch', 'PRIVATE simulated label mismatch', 'private@example.invalid', true)$$, '23505', null, 'A receipt identity cannot be replayed against another tenant token');
select is(lookup_public_point(repeat('a1',16))->'record'->>'state', 'under_investigation', 'Resident input is an unverified concern, not a confirmed finding');
select is(lookup_public_point(repeat('a1',16))->'record'->'concerns'->0->>'source', 'resident_report', 'Public projection retains reported provenance');
select is(lookup_public_point(repeat('a1',16))->'record'->'concerns'->0->>'state', 'reported', 'Resident submission cannot assign its own verification stage');
select is(jsonb_array_length(lookup_public_point(repeat('a1',16))->'record'->'concerns'), 1, 'Receipt retry creates one public concern');
select is(jsonb_array_length(lookup_public_point(repeat('a1',16))->'record'->'tests'), 0, 'Reporting does not create a test');
select ok(lookup_public_point(repeat('a1',16))::text not like '%PRIVATE%' and lookup_public_point(repeat('a1',16))::text not like '%private@example.invalid%', 'Neither free text nor contact appears in public lookup');
select is(jsonb_array_length(lookup_public_point(repeat('a5',16))->'record'->'concerns'), 0, 'Another point in the facility does not inherit the concern');
reset role;
select is((select count(*)::int from audit_events where organization_id = 'c1000000-0000-4000-8000-000000000001'), 1, 'Receipt replay creates one audit event');
select is((select actor_id from audit_events where organization_id = 'c1000000-0000-4000-8000-000000000001'), null::uuid, 'Anonymous input does not impersonate a staff member');

set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from public_concerns), 1, 'Assigned manager can privately review the concern');
select is((select reporter_contact from public_concerns), 'private@example.invalid', 'Consented contact remains available only within authorized review');
select is((select description from public_concerns), 'PRIVATE simulated label mismatch', 'Description is retained privately');
select is((select point_id::text from public_concerns), 'c5000000-0000-4000-8000-000000000001', 'Server derives point identity from the token');
select ok((select submitted_at between statement_timestamp() - interval '1 minute' and clock_timestamp() from public_concerns), 'Throttling uses actual server time, independent of the simulation clock');
select throws_ok($$update public_concerns set contact_consent = false$$, '42501', null, 'Manager cannot overwrite a submitted consent record');
select throws_ok($$delete from public_concerns$$, '42501', null, 'Client cannot erase receipt history');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from public_concerns), 0, 'Laboratory membership does not grant reporter-contact access');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000003","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from public_concerns), 0, 'Field membership does not grant reporter-contact access');
select lives_ok($$select set_config('verify.result', register_sample('c5000000-0000-4000-8000-000000000001', '2026-11-10T10:00:00Z', 'Membrane filtration', 'SIMULATED private transport note', 'c8000000-0000-4000-8000-000000000001')::text, true)$$, 'Field registers a pending sample through its guarded command');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000004","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from public_concerns), 0, 'Sibling-facility manager cannot read private reports');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000005","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from public_concerns), 0, 'Other-tenant manager cannot read private reports');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000006","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from public_concerns), 0, 'Revoked manager loses private report access');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000007","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from public_concerns), 0, 'Expired manager loses private report access');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000008","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from public_concerns), 1, 'Assigned organization administrator can review private reports');
reset role;
set local request.jwt.claims = '{"role":"anon"}';
set local role anon;
select is(lookup_public_point(repeat('a1',16))->>'has_unreviewed_results', 'true', 'Public lookup discloses a pending sample as an aggregate flag');
select is(jsonb_array_length(lookup_public_point(repeat('a1',16))->'record'->'tests'), 0, 'Unreviewed measurements and files remain private');
select is(lookup_public_point(repeat('a5',16))->>'has_unreviewed_results', 'false', 'Pending-sample flag is point scoped');
select is(lookup_public_point(repeat('a3',16))->>'has_unreviewed_results', 'false', 'Pending-sample flag is tenant scoped');

select lives_ok($$select submit_public_concern(('c0000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid, repeat('a1',16), 'other', 'SIMULATED throttling exercise') from generate_series(11,14) n$$, 'A point accepts up to five recent concerns');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'other', 'SIMULATED sixth report')$$, 'PT429', null, 'Sixth recent report is throttled');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a6',16), 'other', 'SIMULATED alternate-label report')$$, 'PT429', null, 'Another active label cannot bypass the point throttle');
select is(submit_public_concern('c0000000-0000-4000-8000-000000000001', repeat('a1',16), 'mismatch', 'PRIVATE simulated label mismatch', 'private@example.invalid', true), current_setting('verify.receipt')::jsonb, 'A valid replay still works at the rate limit');
select lives_ok($$select submit_public_concern(gen_random_uuid(), repeat('a5',16), 'damage', 'SIMULATED other-point concern')$$, 'A separate point has its own rate window');
select lives_ok($$select submit_public_concern(gen_random_uuid(), repeat('a3',16), 'appearance', 'SIMULATED other-tenant concern')$$, 'Public token derives the correct other-tenant scope');
select lives_ok($$select set_config('verify.real', submit_public_concern(gen_random_uuid(), repeat('a4',16), 'other', 'Non-simulation contract fixture; no water observation')::text, true)$$, 'Non-simulation fixture also accepts anonymous input');
select is(current_setting('verify.real')::jsonb->>'is_simulated', 'false', 'Caller cannot forge simulation provenance');
select ok((current_setting('verify.real')::jsonb->>'received_at')::timestamptz between transaction_timestamp() and statement_timestamp(), 'Non-simulated receipt uses actual server time');
reset role;
select is((select organization_id::text from public_concerns where point_id = 'c5000000-0000-4000-8000-000000000003'), 'c1000000-0000-4000-8000-000000000002', 'Other token cannot be attached to the first tenant');
update public_concerns set submitted_at = clock_timestamp() - interval '2 minutes' where point_id = 'c5000000-0000-4000-8000-000000000001';
set local role anon;
select lives_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'smell', 'SIMULATED later report')$$, 'Actual-time window expires while the exercise clock remains fixed');

reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select lives_ok($$
 select transition_result(current_setting('verify.result')::uuid, 'received', 0, '{"custody_note":"SIMULATED sealed handoff"}', 'Receive');
 select transition_result(current_setting('verify.result')::uuid, 'valid', 1, '{}', 'Accept');
 select transition_result(current_setting('verify.result')::uuid, 'tested', 2, '{"indicator":"e_coli","method":"Membrane filtration","value":7.25,"units":"mpn_per100ml","detection_limit":0.125}', 'Synthetic measurement');
 select transition_result(current_setting('verify.result')::uuid, 'reviewed', 3, '{"report_ref":"simulation://PRIVATE-report"}', 'Review');
$$, 'Lab attestation uses the existing guarded lifecycle');
reset role;
set local request.jwt.claims = '{"role":"anon"}';
set local role anon;
select is(lookup_public_point(repeat('a1',16))->>'has_unreviewed_results', 'false', 'Reviewed sample no longer counts as unreviewed');
select is(lookup_public_point(repeat('a1',16))->'record'->>'wording', 'A verified E. coli finding was recorded on 2026-11-10.', 'Confirmed finding stays primary over resident concerns');
select is(jsonb_array_length(lookup_public_point(repeat('a1',16))->'record'->'tests'), 0, 'Attestation does not publish detailed test data');
reset role;
set local request.jwt.claims = '{"sub":"c9000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select lives_ok($$select transition_result(current_setting('verify.result')::uuid, 'published', 4, '{}', 'Publish limited record')$$, 'Manager publishes reviewed evidence separately');
select is(lookup_public_point(repeat('a1',16))->'record'->'tests'->0->>'value', '7.25', 'Public projection retains the precise reported value');
select is(lookup_public_point(repeat('a1',16))->'record'->'tests'->0->>'detection_limit', '0.125', 'Public projection retains the precise detection limit');
select ok(lookup_public_point(repeat('a1',16))::text not like '%PRIVATE%' and lookup_public_point(repeat('a1',16))::text not like '%private@example.invalid%', 'Published envelope excludes private report references, staff notes and contact');
select lives_ok($$select revoke_public_record(repeat('a1',16), 'Replace simulated printed label')$$, 'Manager revokes a label through its audited command');
reset role;
set local request.jwt.claims = '{"role":"anon"}';
set local role anon;
select is(lookup_public_point(repeat('a1',16)), '{"status":"revoked"}'::jsonb, 'Revoked label returns explicit status with no point evidence');
select is(lookup_public_record(repeat('a1',16)), null::jsonb, 'Legacy lookup still returns null for revoked labels');
select throws_ok($$select submit_public_concern('c0000000-0000-4000-8000-000000000001', repeat('a1',16), 'mismatch', 'PRIVATE simulated label mismatch', 'private@example.invalid', true)$$, 'PT410', null, 'Revocation is checked before replaying a receipt');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('a1',16), 'other', 'SIMULATED new report')$$, 'PT410', null, 'Revoked labels cannot submit new concerns');
select throws_ok($$select submit_public_concern(gen_random_uuid(), repeat('ff',16), 'other', 'SIMULATED unknown label')$$, 'PT410', null, 'Unknown labels cannot submit concerns');
select is(lookup_public_point(repeat('a6',16))->>'status', 'found', 'Another issued label remains bound to the original point');

reset role;
-- Even a malformed trusted import cannot borrow a finding from another scope.
insert into incidents(organization_id, facility_id, system_id, point_ids, source, source_id, reported_at, is_simulated) values
 ('c1000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000003', array['c5000000-0000-4000-8000-000000000003']::uuid[], 'laboratory', current_setting('verify.result')::uuid, '2026-11-10T12:00:00Z', true);
insert into samples(id, code, organization_id, facility_id, point_id, collector_id, collected_at, intended_method, preservation_note, is_simulated) values
 ('c8000000-0000-4000-8000-000000000002', 'SIMULATED-PUBLIC-SCOPE', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000001', 'c9000000-0000-4000-8000-000000000003', '2026-11-10T09:00:00Z', 'Membrane filtration', 'Synthetic malformed-import fixture', true);
insert into test_results(id, organization_id, facility_id, sample_id, state, indicator, method, value, units, detection_limit, received_at, tested_at, reviewed_at, reviewed_by, report_ref, is_simulated) values
 ('c7000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'c8000000-0000-4000-8000-000000000002', 'reviewed', 'e_coli', 'Membrane filtration', 9.75, 'mpn_per100ml', 0.125, '2026-11-10T09:30:00Z', '2026-11-10T10:00:00Z', '2026-11-10T11:00:00Z', 'c9000000-0000-4000-8000-000000000002', 'simulation://PRIVATE-scope-test', true);
insert into incidents(organization_id, facility_id, system_id, point_ids, source, source_id, reported_at, is_simulated) values
 ('c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', array['c5000000-0000-4000-8000-000000000005']::uuid[], 'laboratory', 'c7000000-0000-4000-8000-000000000001', '2026-11-10T12:00:00Z', true);
set local role anon;
select is(lookup_public_point(repeat('a3',16))->'record'->>'state', 'under_investigation', 'A source ID cannot borrow a confirmed finding from another tenant');
select is(lookup_public_point(repeat('a5',16))->'record'->>'state', 'under_investigation', 'A source ID cannot borrow a confirmed finding from another point');
select is(jsonb_array_length(lookup_public_point(repeat('a3',16))->'record'->'tests'), 0, 'Other-tenant evidence detail never crosses the projection');
select is(jsonb_array_length(lookup_public_point(repeat('a5',16))->'record'->'tests'), 0, 'Other-point evidence detail never crosses the projection');
reset role;
select * from finish();
rollback;
