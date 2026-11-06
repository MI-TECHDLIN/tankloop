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
insert into storage.objects(bucket_id,name,owner,metadata) values ('inspection-evidence',
  '90000000-0000-4000-8000-000000000001/inspections/b1000000-0000-4000-8000-000000000001.jpg',auth.uid(),'{"mimetype":"image/jpeg"}');
select set_config('test.photos','[{"id":"b1000000-0000-4000-8000-000000000001","path":"90000000-0000-4000-8000-000000000001/inspections/b1000000-0000-4000-8000-000000000001.jpg","question_id":"lid","captured_at":"2026-11-13T12:00:00Z"}]',true);
select lives_ok($$select set_config('test.receipt',submit_inspection_with_evidence('a1000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000001',0,'{"lid":{"choice":"yes"}}','Photo observation','2026-11-13T12:00:00Z',current_setting('test.photos')::jsonb)::text,true)$$,
  'Inspection and private photo link commit together despite device clock skew');
select is((select count(*)::int from field_evidence),1,'Photo metadata is attached once');
select is((select question_id from field_evidence),'lid','Photo is linked to the specific answer');
select is((select captured_at from field_evidence),'2026-11-13T12:00:00Z'::timestamptz,'Device capture time retained');
select is(submit_inspection_with_evidence('a1000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000001',0,'{"lid":{"choice":"yes"}}','Photo observation','2026-11-13T12:00:00Z',current_setting('test.photos')::jsonb),
  current_setting('test.receipt')::jsonb,'Lost receipt retry returns identical receipt');
select is((select count(*)::int from field_evidence),1,'Retry does not duplicate metadata');
select is((select count(*)::int from incidents),1,'Retry does not duplicate incident');
select throws_ok($$select submit_inspection_with_evidence('a1000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000001',0,'{"lid":{"choice":"yes"}}','Photo observation','2026-11-13T12:00:00Z','[]')$$,
  '23505',null,'Acknowledged photo manifest cannot change');
with changed as (update storage.objects set metadata = '{}' where bucket_id = 'inspection-evidence' returning id) select is((select count(*)::int from changed),0,
  'Acknowledged photo bytes cannot be overwritten');
select throws_ok($$select submit_inspection_with_evidence('a1000000-0000-4000-8000-000000000002',
  '70000000-0000-4000-8000-000000000004',0,'{"lid":{"choice":"no"}}','','2026-11-10T12:00:00Z',
  '[{"id":"b1000000-0000-4000-8000-000000000002","path":"missing","captured_at":"2026-11-10T12:00:00Z"}]')$$,
  '22023',null,'Partial upload cannot commit an incomplete inspection');
select is((select version from inspections where id = '70000000-0000-4000-8000-000000000004'),0,'Partial upload rolls back inspection version');
select throws_ok($$select submit_inspection_with_evidence('a1000000-0000-4000-8000-000000000003',
  '70000000-0000-4000-8000-000000000002',0,'{"lid":{"choice":"no"}}','','2026-11-10T12:00:00Z','[]')$$,
  '42501',null,'Field photo command cannot cross facility scope');

reset role;
insert into public.work_orders(id,organization_id,facility_id,incident_id,task,state,assignee_id,approved_by,is_simulated)
 select 'c1000000-0000-4000-8000-000000000001',organization_id,facility_id,id,'Test repair','in_progress',
 '90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002',true from public.incidents where organization_id = '10000000-0000-4000-8000-000000000001';
set local role authenticated;
insert into storage.objects(bucket_id,name,owner,metadata) values ('inspection-evidence',
 '90000000-0000-4000-8000-000000000001/inspections/b1000000-0000-4000-8000-000000000002.jpg',auth.uid(),'{"mimetype":"image/jpeg"}');
select set_config('test.workphotos','[{"id":"b1000000-0000-4000-8000-000000000002","path":"90000000-0000-4000-8000-000000000001/inspections/b1000000-0000-4000-8000-000000000002.jpg","captured_at":"2026-11-10T12:00:00Z"}]',true);
select lives_ok($$select set_config('test.workreceipt',submit_work_step('a2000000-0000-4000-8000-000000000001',
  'c1000000-0000-4000-8000-000000000001',0,'completed','Lid secured','2026-11-10T12:00:00Z',current_setting('test.workphotos')::jsonb)::text,true)$$,
  'Assigned worker records completed step with photo');
select is(submit_work_step('a2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001',0,
  'completed','Lid secured','2026-11-10T12:00:00Z',current_setting('test.workphotos')::jsonb),current_setting('test.workreceipt')::jsonb,'Work step retry returns same receipt');
select is((select state::text from incidents),'reported','Work completion never closes concern');
select is((select count(*)::int from field_evidence where step = 'completed'),1,'Photo linked to exact work step');
reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000004","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from field_evidence),0,'Another tenant cannot read attachment metadata');
select is((select count(*)::int from storage.objects where bucket_id = 'inspection-evidence'),0,'Another tenant cannot read photo bytes');
reset role;
set local request.jwt.claims = '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from field_evidence),2,'Scoped manager can review attachments');
select is((select count(*)::int from storage.objects where bucket_id = 'inspection-evidence'),2,'Scoped manager can request private file access');
reset role;
set local role anon;
select throws_ok($$select * from field_evidence$$,'42501',null,'Public role cannot read evidence metadata');
select is((select count(*)::int from storage.objects where bucket_id = 'inspection-evidence'),0,'Public QR visitors cannot read files');
reset role;
select * from finish();
rollback;
