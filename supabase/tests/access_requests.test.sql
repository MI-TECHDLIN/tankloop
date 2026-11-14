-- Self-service access requests: simulated facilities auto-approve for demos;
-- non-simulated facilities remain pending until an organization admin decides.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into public.organizations(id,name,is_simulated,settings) values
 ('a1000000-0000-4000-8000-000000000001','Simulated demo cooperative',true,'{"simulation_clock":"2026-11-14T12:00:00Z"}'),
 ('a1000000-0000-4000-8000-000000000002','Real customer cooperative',false,'{}');
insert into public.facilities(id,organization_id,public_label,is_simulated) values
 ('b1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','Demo court',true),
 ('b1000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002','Customer court',false);
insert into auth.users(id,email) values
 ('c1000000-0000-4000-8000-000000000001','demo-requester@tankloop.invalid'),
 ('c1000000-0000-4000-8000-000000000002','real-requester@tankloop.invalid'),
 ('c1000000-0000-4000-8000-000000000003','real-admin@tankloop.invalid');
insert into public.memberships(user_id,organization_id,facility_id,role,status,is_simulated) values
 ('c1000000-0000-4000-8000-000000000003','a1000000-0000-4000-8000-000000000002',null,'admin','active',false);

set local request.jwt.claims = '{"sub":"c1000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select ok((select count(*) from jsonb_array_elements(list_joinable_facilities()) f where f->>'facility_id' = 'b1000000-0000-4000-8000-000000000001') = 1,'Simulated facility is listed for self-service');
select ok((select count(*) from jsonb_array_elements(list_joinable_facilities()) f where f->>'facility_id' = 'b1000000-0000-4000-8000-000000000002') = 0,'Non-simulated facility is not listed for self-service');
select lives_ok($$select set_config('test.sim_request',request_access('b1000000-0000-4000-8000-000000000001','field')::text,true)$$,'Simulated facility accepts a field request');
select is((select status from public.access_requests where id = current_setting('test.sim_request')::uuid),'approved','Simulated request is approved immediately');
select ok((select decided_by from public.access_requests where id = current_setting('test.sim_request')::uuid) is null,'Automatic approval does not impersonate an administrator');
select is((select role::text from public.memberships where user_id = 'c1000000-0000-4000-8000-000000000001' and facility_id = 'b1000000-0000-4000-8000-000000000001'),'field','Approval creates the scoped membership');
select is((select new_state from public.audit_events where aggregate_id = current_setting('test.sim_request')),'approved','Automatic approval is audited');
select throws_ok($$select request_access('b1000000-0000-4000-8000-000000000001','admin')$$,'22023',null,'Self-service cannot request the administrator role');
select throws_ok($$select request_access('b1000000-0000-4000-8000-000000000001','field')$$,'22023',null,'An active approved membership cannot be requested again');

reset role;
set local request.jwt.claims = '{"sub":"c1000000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;
select lives_ok($$select set_config('test.real_request',request_access('b1000000-0000-4000-8000-000000000002','manager')::text,true)$$,'Non-simulated facility accepts a pending request');
select is((select status from public.access_requests where id = current_setting('test.real_request')::uuid),'pending','Non-simulated request waits for administrator review');
select is((select count(*)::int from public.memberships where user_id = 'c1000000-0000-4000-8000-000000000002'),0,'Pending request creates no membership');
select throws_ok($$select review_access_request(current_setting('test.real_request')::uuid,true,null)$$,'42501',null,'A requester cannot approve their own access');

reset role;
set local request.jwt.claims = '{"sub":"c1000000-0000-4000-8000-000000000003","role":"authenticated"}';
set local role authenticated;
select is((review_access_request(current_setting('test.real_request')::uuid,true,null)->>'status'),'approved','Organization admin approves the pending request');
reset role;
select is((select role::text from public.memberships where user_id = 'c1000000-0000-4000-8000-000000000002' and facility_id = 'b1000000-0000-4000-8000-000000000002'),'manager','Admin approval creates the requested membership');

select * from finish();
rollback;
