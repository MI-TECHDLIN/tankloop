-- Behavioral tests against the real RPC and RLS boundary. Each role below is
-- the database role/JWT identity PostgREST uses, not a client-side role toggle.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into public.organizations(id,name,settings,is_simulated) values
 ('10000000-0000-4000-8000-000000000001','Test cooperative A','{"simulation_clock":"2026-11-10T12:00:00Z"}',true),
 ('10000000-0000-4000-8000-000000000002','Test cooperative B','{"simulation_clock":"2026-11-10T12:00:00Z"}',true);
insert into public.facilities(id,organization_id,public_label,is_simulated) values
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Test court A',true),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Other court A',true),
 ('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','Test court B',true);
insert into auth.users(id,email) values
 ('90000000-0000-4000-8000-000000000001','test-field@tankloop.invalid'),
 ('90000000-0000-4000-8000-000000000002','test-manager@tankloop.invalid'),
 ('90000000-0000-4000-8000-000000000003','test-lab@tankloop.invalid'),
 ('90000000-0000-4000-8000-000000000004','test-other@tankloop.invalid'),
 ('90000000-0000-4000-8000-000000000005','test-revoked@tankloop.invalid'),
 ('90000000-0000-4000-8000-000000000006','test-expired@tankloop.invalid'),
 ('90000000-0000-4000-8000-000000000007','test-admin@tankloop.invalid');
insert into public.memberships(user_id,organization_id,facility_id,role,status,valid_until,is_simulated) values
 ('90000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','field','active',null,true),
 ('90000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','manager','active',null,true),
 ('90000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','lab','active',null,true),
 ('90000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000003','field','active',null,true),
 ('90000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','field','revoked',null,true),
 ('90000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','field','active',now()-interval '1 day',true),
 ('90000000-0000-4000-8000-000000000007','10000000-0000-4000-8000-000000000001',null,'admin','active',null,true);
insert into public.water_systems(id,organization_id,facility_id,label,is_simulated)
 select replace(id::text,'20000000','30000000')::uuid,organization_id,id,'Test network',true from public.facilities where id::text like '20000000-%';
insert into public.assets(id,organization_id,facility_id,system_id,type,label,is_simulated)
 select replace(id::text,'30000000','40000000')::uuid,organization_id,facility_id,id,'tank','Test tank',true from public.water_systems where id::text like '30000000-%';
insert into public.sampling_points(id,organization_id,facility_id,asset_id,label,is_simulated)
 select replace(id::text,'40000000','50000000')::uuid,organization_id,facility_id,id,'Test outlet',true from public.assets where id::text like '40000000-%';
insert into public.checklist_templates(id,organization_id,facility_id,version,title,source,asset_type,questions,is_simulated)
 select replace(id::text,'20000000','60000000')::uuid,organization_id,id,1,'Test checklist','Test fixture, not field guidance','tank','[{"id":"lid","label":"Cover missing?","required":true}]',true from public.facilities where id::text like '20000000-%';
insert into public.inspections(id,organization_id,facility_id,asset_id,template_id,assigned_to,due_at,is_simulated)
 select replace(id::text,'20000000','70000000')::uuid,organization_id,id,replace(id::text,'20000000','40000000')::uuid,replace(id::text,'20000000','60000000')::uuid,
   case when id = '20000000-0000-4000-8000-000000000003' then '90000000-0000-4000-8000-000000000004'::uuid else '90000000-0000-4000-8000-000000000001'::uuid end,
   '2026-11-10T11:00:00Z',true from public.facilities where id::text like '20000000-%';
insert into public.inspections(id,organization_id,facility_id,asset_id,template_id,assigned_to,due_at,is_simulated)
 select ('70000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001','2026-11-10T15:00:00Z',true from generate_series(4,6) n;
insert into public.public_records(organization_id,facility_id,point_id,token,is_simulated)
 select organization_id,facility_id,id,repeat(right(id::text,1),32),true from public.sampling_points where id::text like '50000000-%';

set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from organizations),1,'Field user sees only their organization');
select is((select count(*)::int from facilities),1,'Facility membership does not grant sibling facility access');
select is((select count(*)::int from assets),1,'Asset reads enforce the facility boundary');
select is((select count(*)::int from memberships),1,'A user can read only their own memberships');
select is((select count(*)::int from inspections where facility_id = '20000000-0000-4000-8000-000000000003'),0,'Cross-tenant inspections are invisible');
select throws_ok($$update memberships set role = 'admin'$$,'42501',null,'A field client cannot promote itself');
select throws_ok($$update inspections set state = 'submitted'$$,'42501',null,'A client cannot bypass the inspection command');
select throws_ok($$delete from audit_events$$,'42501',null,'A client cannot erase audit');
select throws_ok($$select submit_inspection('a1000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002',0,'{"lid":{"choice":"no"}}','','2026-11-10T11:00:00Z')$$,'42501',null,'Known IDs cannot bypass same-organization facility scope');
select throws_ok($$select submit_inspection('a1000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000003',0,'{"lid":{"choice":"no"}}','','2026-11-10T11:00:00Z')$$,'42501',null,'Known IDs cannot bypass tenant scope');
select throws_ok($$select submit_inspection('a1000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001',0,'{}','','2026-11-10T11:00:00Z')$$,'22023',null,'Required checklist items cannot be omitted');
select lives_ok($$select set_config('test.receipt',submit_inspection('a1000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001',0,'{"lid":{"choice":"yes","note":"Private observation"}}','Private staff notes','2026-11-10T11:00:00Z')::text,true)$$,'Assigned inspector submits observed risk');
select is((select source::text from incidents),'inspection','An inspection creates an observed-risk case, not laboratory evidence');
select is(submit_inspection('a1000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001',0,'{"lid":{"choice":"yes","note":"Private observation"}}','Private staff notes','2026-11-10T11:00:00Z'),current_setting('test.receipt')::jsonb,'A lost-ACK retry receives the exact same receipt');
select is((select count(*)::int from incidents),1,'Duplicate delivery creates only one incident');
select is((select count(*)::int from audit_events),2,'Duplicate delivery does not duplicate audit');
select is((select observed_at from inspections where id = '70000000-0000-4000-8000-000000000001'),'2026-11-10T11:00:00Z'::timestamptz,'Device observation time is retained');
select is((current_setting('test.receipt')::jsonb->>'received_at')::timestamptz,'2026-11-10T12:00:00Z'::timestamptz,'Receipt uses the canonical simulated server clock');
select throws_ok($$select submit_inspection('a1000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001',0,'{"lid":{"choice":"no"}}','','2026-11-10T11:00:00Z')$$,'23505',null,'Idempotency keys cannot silently change content');
select throws_ok($$select submit_inspection('a1000000-0000-4000-8000-000000000002','70000000-0000-4000-8000-000000000001',0,'{"lid":{"choice":"no"}}','','2026-11-10T11:00:00Z')$$,'40001',null,'Competing submission cannot overwrite an accepted inspection');
select lives_ok($$select set_config('test.result',register_sample('50000000-0000-4000-8000-000000000001','2026-11-10T10:00:00Z','Membrane filtration','Simulated sealed transport','80000000-0000-4000-8000-000000000001')::text,true)$$,'Collector registers a uniquely identified sample');
select is(register_sample('50000000-0000-4000-8000-000000000001','2026-11-10T10:00:00Z','Membrane filtration','Simulated sealed transport','80000000-0000-4000-8000-000000000001'),current_setting('test.result')::uuid,'Sample registration retry preserves identity');
select throws_ok($$select transition_result(current_setting('test.result')::uuid,'received',0,'{}','Receive')$$,'42501',null,'Field role cannot attest laboratory intake');
select throws_ok($$select revoke_public_record(repeat('1',32),'Replace label')$$,'42501',null,'Field role cannot revoke public identity');

reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000005","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from assets),0,'Revoked membership loses reads immediately');
select throws_ok($$select submit_inspection('a1000000-0000-4000-8000-000000000005','70000000-0000-4000-8000-000000000004',0,'{"lid":{"choice":"no"}}','','2026-11-10T11:00:00Z')$$,'42501',null,'Revoked membership cannot upload queued work');
reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000006","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from facilities),0,'Expiry uses actual server time even for simulated organizations');
reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000007","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from facilities),2,'Organization administrator can read both assigned-organization facilities');
select throws_ok($$select transition_result(current_setting('test.result')::uuid,'received',0,'{}','Receive')$$,'42501',null,'Organization admin cannot impersonate a lab reviewer');

reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000003","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select transition_result(current_setting('test.result')::uuid,'reviewed',0,'{"report_ref":"simulation://test/report"}','Skip intake')$$,'22023',null,'Laboratory role cannot skip intake and testing');
select is(transition_result(current_setting('test.result')::uuid,'received',0,'{"custody_note":"Simulated sealed handoff"}','Receive sample'),1,'Lab intake records received state');
select is((select count(*)::int from custody_events),1,'Lab receipt appends a custody event');
select is(transition_result(current_setting('test.result')::uuid,'valid',1,'{}','Accept seal and timing'),2,'Lab validates sample integrity');
select throws_ok($$select transition_result(current_setting('test.result')::uuid,'tested',2,'{"indicator":"e_coli","method":"Other method","value":8,"units":"cfu_per100ml","detection_limit":1}','Test')$$,'22023',null,'Unexpected test method is rejected');
select throws_ok($$select transition_result(current_setting('test.result')::uuid,'tested',2,'{"indicator":"e_coli","method":"Membrane filtration","value":-1,"units":"cfu_per100ml","detection_limit":1}','Test')$$,'23514',null,'Negative microbial counts cannot be entered');
select is(transition_result(current_setting('test.result')::uuid,'tested',2,'{"indicator":"e_coli","method":"Membrane filtration","value":8,"units":"cfu_per100ml","detection_limit":1}','Synthetic test entered'),3,'A lab result retains value, units and detection limit');
select is((select count(*)::int from incidents where source = 'laboratory'),0,'Unreviewed values cannot become confirmed incidents');
select throws_ok($$select transition_result(current_setting('test.result')::uuid,'reviewed',3,'{}','Attest')$$,'22023',null,'Attestation requires a linked report');
select is(transition_result(current_setting('test.result')::uuid,'reviewed',3,'{"report_ref":"simulation://test/private-report"}','Qualified review'),4,'Lab reviewer attests the linked evidence');
select is((select count(*)::int from incidents where source = 'laboratory'),1,'Reviewed E. coli finding opens an auditable incident');
select throws_ok($$select transition_result(current_setting('test.result')::uuid,'published',4,'{}','Publish')$$,'42501',null,'Publication requires manager authority distinct from laboratory review');
select lives_ok($$select set_config('test.incident',(select id::text from incidents where source = 'laboratory'),true)$$,'Remember the confirmed case for the operational journey');

reset role;
set local request.jwt.claims = '{"role":"anon"}';
set local role anon;
select throws_ok($$select * from test_results$$,'42501',null,'Anonymous readers cannot enumerate results');
select throws_ok($$select * from public_records$$,'42501',null,'Anonymous readers cannot enumerate point tokens');
select throws_ok($$select * from inspections$$,'42501',null,'Anonymous readers cannot access inspection notes');
select is((select public from storage.buckets where id = 'inspection-evidence'),false,'Inspection evidence bucket is private by default');
select ok(
  (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'field members upload own evidence') = 1,
  'Private evidence upload policy is present'
);
select ok(
  (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'field members read own evidence') = 1,
  'Private evidence read policy is present'
);
select throws_ok($$insert into storage.objects (bucket_id,name,owner,metadata) values ('inspection-evidence','90000000-0000-4000-8000-000000000001/inspections/anonymous.jpg',auth.uid(),'{}')$$,'42501',null,'Anonymous users cannot write private evidence');
select throws_ok($$select submit_inspection('a1000000-0000-4000-8000-000000000008','70000000-0000-4000-8000-000000000004',0,'{}','','2026-11-10T11:00:00Z')$$,'42501',null,'Anonymous mutation is denied');
select is(lookup_public_record('not-a-token'),null::jsonb,'Malformed public token reveals nothing');
select is(lookup_public_record(repeat('f',32)),null::jsonb,'Unknown public token reveals nothing');
select is(lookup_public_record(repeat('1',32))->>'state','confirmed_finding','A confirmed concern is visible before publication of test detail');
select is(jsonb_array_length(lookup_public_record(repeat('1',32))->'tests'),0,'Unpublished evidence detail remains private');
select is(lookup_public_record(repeat('1',32))->>'wording','A verified E. coli finding was recorded on 2026-11-10.','Public finding uses the evidence-limited wording');
select ok(not (lookup_public_record(repeat('1',32)) ?| array['notes','report_ref','actor_id','reviewed_by','point_id','latitude','longitude']),'Public record omits internal identity, notes, coordinates and attachments');
select is(lookup_public_record(repeat('2',32))->>'wording','We do not have a current verified test record for this point.','An empty point makes no water-quality claim');

reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select is(transition_result(current_setting('test.result')::uuid,'published',4,'{}','Publish limited sample record'),5,'Manager publishes the reviewed result');
select throws_ok($$select transition_result(current_setting('test.result')::uuid,'received',5,'{}','Rewrite')$$,'42501',null,'Manager cannot rewrite laboratory provenance');
select throws_ok($$select transition_incident(current_setting('test.incident')::uuid,'resolved',0,'{"communication_ref":"notice"}','Close early')$$,'22023',null,'A reported finding cannot jump directly to resolved');
select throws_ok($$select transition_incident(current_setting('test.incident')::uuid,'triaged',0,'{"priority":"urgent"}','Triage')$$,'22023',null,'Triage requires recorded uncertainty');
select is(transition_incident(current_setting('test.incident')::uuid,'triaged',0,'{"priority":"urgent","uncertainty":"Single point; wider scope unknown"}','Triage'),1,'Manager classifies urgency and uncertainty');
select throws_ok($$select transition_incident(current_setting('test.incident')::uuid,'assigned',1,'{"owner_id":"90000000-0000-4000-8000-000000000004","due_at":"2026-11-12T12:00:00Z","required_response":"Review asset"}','Assign')$$,'22023',null,'Cannot assign an owner from another tenant');
select is(transition_incident(current_setting('test.incident')::uuid,'assigned',1,'{"owner_id":"90000000-0000-4000-8000-000000000001","due_at":"2026-11-12T12:00:00Z","required_response":"Review asset"}','Assign accountable owner'),2,'Manager assigns a scoped owner and deadline');
select throws_ok($$select escalate_incident(current_setting('test.incident')::uuid,2,'Premature escalation')$$,'22023',null,'Routine timing cannot be escalated before a deadline without critical priority');
select throws_ok($$select transition_incident(current_setting('test.incident')::uuid,'mitigation',2,'{}','Start')$$,'22023',null,'Mitigation requires authorized work');
select is(propose_work_order('a2000000-0000-4000-8000-000000000001',current_setting('test.incident')::uuid,'Inspect cover and fittings'),'a2000000-0000-4000-8000-000000000001'::uuid,'Work proposal links to the case');
select is(transition_work_order('a2000000-0000-4000-8000-000000000001','approval_pending',0,'{}','Request approval'),1,'Proposal enters approval queue');

reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select transition_work_order('a2000000-0000-4000-8000-000000000001','assigned',1,'{"assignee_id":"90000000-0000-4000-8000-000000000001","due_at":"2026-11-12T12:00:00Z"}','Self approve')$$,'42501',null,'A field worker cannot approve their own work');
select throws_ok($$select transition_incident(current_setting('test.incident')::uuid,'resolved',2,'{}','Close')$$,'42501',null,'A field worker cannot close a case');

-- Progress the trusted simulation clock to distinguish post-action evidence
-- from old observations uploaded only after the repair.
reset role;
update organizations set settings = '{"simulation_clock":"2026-11-10T14:00:00Z"}' where id = '10000000-0000-4000-8000-000000000001';
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select is(transition_work_order('a2000000-0000-4000-8000-000000000001','assigned',1,'{"assignee_id":"90000000-0000-4000-8000-000000000001","due_at":"2026-11-12T12:00:00Z"}','Approve work'),2,'Manager approves and assigns the work');
select is(transition_incident(current_setting('test.incident')::uuid,'mitigation',2,'{}','Authorized work started'),3,'Incident enters mitigation independently of the work order');
select is(lookup_public_record(repeat('1',32))->>'state','confirmed_finding','Friendly maintenance status cannot hide a confirmed finding');
select is(lookup_public_record(repeat('1',32))->>'action_wording','Work is underway. Verification has not yet been completed.','Public response explicitly says verification is incomplete');
select throws_ok($$select set_verification_plan(current_setting('test.incident')::uuid,3,'[{"kind":"sample","point_id":"50000000-0000-4000-8000-000000000001","indicator":"total_coliforms","method":"Membrane filtration"}]','Wrong indicator')$$,'22023',null,'A different indicator cannot replace E. coli verification');
select is(set_verification_plan(current_setting('test.incident')::uuid,3,'[{"kind":"sample","point_id":"50000000-0000-4000-8000-000000000001","indicator":"e_coli","method":"Membrane filtration"},{"kind":"checklist","template_id":"60000000-0000-4000-8000-000000000001"}]','Define complete follow-up'),4,'Plan includes the affected point and checklist');

reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select is(transition_work_order('a2000000-0000-4000-8000-000000000001','in_progress',2,'{}','Begin assigned work'),3,'Assigned worker starts work');
select throws_ok($$select transition_work_order('a2000000-0000-4000-8000-000000000001','completed',3,'{}','Complete')$$,'22023',null,'Completion requires evidence');
select is(transition_work_order('a2000000-0000-4000-8000-000000000001','completed',3,'{"completion_evidence":"simulation://work/photo"}','Record repair'),4,'Worker records repair evidence');
select is((select state::text from incidents where id = current_setting('test.incident')::uuid),'mitigation','Repair completion does not resolve the incident');
select lives_ok($$select submit_inspection('a1000000-0000-4000-8000-000000000005','70000000-0000-4000-8000-000000000005',0,'{"lid":{"choice":"no"}}','Old offline observation','2026-11-10T11:00:00Z')$$,'An older offline observation can sync with its original timestamp');

reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select is(transition_work_order('a2000000-0000-4000-8000-000000000001','accepted',4,'{}','Review repair evidence'),5,'Manager accepts work evidence');
select throws_ok($$select transition_incident(current_setting('test.incident')::uuid,'verification_pending',4,'{"controls_reviewed":true}','Retest')$$,'22023',null,'Verification requires reviewed controls and a recorded notice');
select is(transition_incident(current_setting('test.incident')::uuid,'verification_pending',4,'{"controls_reviewed":true,"notice_reviewed":true,"notice_ref":"simulation://interim-notice"}','Request follow-up'),5,'Accepted work moves the incident only to verification pending');
select throws_ok($$select transition_incident(current_setting('test.incident')::uuid,'resolved',5,'{"communication_ref":"simulation://notice"}','Attempt closure')$$,'22023',null,'Missing negative follow-up keeps the incident open');

reset role;
update organizations set settings = '{"simulation_clock":"2026-11-10T16:00:00Z"}' where id = '10000000-0000-4000-8000-000000000001';
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select lives_ok($$select set_config('test.followup',register_sample('50000000-0000-4000-8000-000000000001','2026-11-10T15:00:00Z','Membrane filtration','Simulated sealed follow-up','80000000-0000-4000-8000-000000000002')::text,true)$$,'A new post-repair sample is registered');
reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000003","role":"authenticated"}';
set local role authenticated;
select lives_ok($$select transition_result(current_setting('test.followup')::uuid,'received',0,'{}','Receive'); select transition_result(current_setting('test.followup')::uuid,'valid',1,'{}','Validate'); select transition_result(current_setting('test.followup')::uuid,'tested',2,'{"indicator":"e_coli","method":"Membrane filtration","value":0,"units":"cfu_per100ml","detection_limit":1}','Test'); select transition_result(current_setting('test.followup')::uuid,'reviewed',3,'{"report_ref":"simulation://follow-up"}','Review')$$,'Lab reviews a scoped negative follow-up');
reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select transition_incident(current_setting('test.incident')::uuid,'resolved',5,'{"communication_ref":"simulation://notice"}','Attempt closure')$$,'22023',null,'An old observation received after repair cannot satisfy a post-action checklist');
reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select lives_ok($$select submit_inspection('a1000000-0000-4000-8000-000000000006','70000000-0000-4000-8000-000000000006',0,'{"lid":{"choice":"no"}}','Post-action observation','2026-11-10T15:00:00Z')$$,'Field worker records the actual post-action checklist');
reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select transition_incident(current_setting('test.incident')::uuid,'resolved',5,'{}','Attempt closure')$$,'22023',null,'Complete evidence without recorded communication cannot close a case');
select is(transition_incident(current_setting('test.incident')::uuid,'resolved',5,'{"communication_ref":"simulation://closure-notice"}','All applicable verification fulfilled'),6,'Manager resolves only after the complete plan and communication');
select is(transition_result(current_setting('test.followup')::uuid,'published',4,'{}','Publish dated follow-up'),5,'Reviewed follow-up is published separately from closure');

-- Corrections preserve the original, open a new finding when appropriate, and
-- can support reopening of the original incident without erasing its closure.
reset role;
update organizations set settings = '{"simulation_clock":"2026-11-10T17:00:00Z"}' where id = '10000000-0000-4000-8000-000000000001';
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000003","role":"authenticated"}';
set local role authenticated;
select throws_ok($$select correct_result(current_setting('test.followup')::uuid,5,4,'simulation://correction','')$$,'22023',null,'Correction needs an explicit reason');
select lives_ok($$select set_config('test.revision',correct_result(current_setting('test.followup')::uuid,5,4,'simulation://corrected-report','Transcription correction')::text,true)$$,'Authorized correction creates a new revision');
select is((select state::text from test_results where id = current_setting('test.followup')::uuid),'superseded','Original result remains as superseded evidence');
select is((select value from test_results where id = current_setting('test.followup')::uuid),0::numeric,'Original measured value is retained');
select is((select revision_of from test_results where id = current_setting('test.revision')::uuid),current_setting('test.followup')::uuid,'Revision links to its original');
select is((select correction_reason from test_results where id = current_setting('test.revision')::uuid),'Transcription correction','Correction preserves its reason');
select is((select corrected_by from test_results where id = current_setting('test.revision')::uuid),'90000000-0000-4000-8000-000000000003'::uuid,'Correction preserves its authorized actor');
select is((select corrected_at from test_results where id = current_setting('test.revision')::uuid),'2026-11-10T17:00:00Z'::timestamptz,'Correction preserves its canonical time');
select is((select published_at from test_results where id = current_setting('test.revision')::uuid),null::timestamptz,'Correction requires a fresh publication decision');
reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select is(transition_incident(current_setting('test.incident')::uuid,'reopened',6,jsonb_build_object('cause','repeat_verified_finding','evidence_ref',current_setting('test.revision')),'Repeat reviewed finding'),7,'A reviewed repeat finding can reopen a resolved incident');
select is((select resolved_at from incidents where id = current_setting('test.incident')::uuid),'2026-11-10T16:00:00Z'::timestamptz,'Reopening preserves the earlier closure timestamp');
select is(lookup_public_record(repeat('1',32))->>'state','confirmed_finding','Reopening and corrections cannot hide an active finding behind normal history');
select ok(not ((lookup_public_record(repeat('1',32))->'tests'->0) ?| array['report_ref','reviewed_by','sample_id']),'Published tests omit private report and staff identifiers');
select lives_ok($$select revoke_public_record(repeat('1',32),'Printed sticker replaced')$$,'Manager revokes a printed point token');
select is(lookup_public_record(repeat('1',32)),null::jsonb,'Revoked QR immediately stops resolving');
select is((select count(*)::int from audit_events where aggregate_id = repeat('1',32) and new_state = 'revoked'),1,'QR revocation is audited');

reset role;
select throws_ok($$update public_records set point_id = '50000000-0000-4000-8000-000000000002' where token = repeat('1',32)$$,'42501',null,'Even trusted provisioning cannot silently reattach a token');
select throws_ok($$update public_records set revoked_at = null where token = repeat('1',32)$$,'42501',null,'Revocation is permanent for the old token');
select throws_ok($$update test_results set value = 123 where id = current_setting('test.followup')::uuid$$,'42501',null,'Superseded original cannot be overwritten');
select throws_ok($$delete from test_results where id = current_setting('test.followup')::uuid$$,'42501',null,'Scientific evidence cannot be deleted');
select throws_ok($$update audit_events set reason = 'Rewritten' where organization_id = '10000000-0000-4000-8000-000000000001'$$,'42501',null,'Audit history is append-only, including for trusted callers');
select throws_ok($$update samples set collected_at = now() where id = '80000000-0000-4000-8000-000000000001'$$,'42501',null,'Sample collection identity and time are immutable');
select throws_ok($$update checklist_templates set version = 2 where id = '60000000-0000-4000-8000-000000000001'$$,'42501',null,'Issued checklist version is immutable');
select throws_ok($$insert into sampling_points(organization_id,facility_id,asset_id,label,is_simulated) values('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000003','Bad cross-tenant point',true)$$,'23503',null,'Composite foreign keys reject cross-tenant asset references');
select throws_ok($$insert into sampling_points(organization_id,facility_id,asset_id,label,is_simulated) values('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','Unlabelled simulation',false)$$,'23514',null,'Simulated evidence cannot lose its simulation label');
select * from finish();
rollback;
