# TankLoop Lab

Lab runs in `apps/portal_web` alongside Verify and Manage. Open `/#/lab` on the Portal origin. It redirects to `/#/lab/inbox`; the other routes are `/#/lab/intake`, `/#/lab/results` and `/#/lab/revisions`. A `?record=<RESULT_UUID>` query selects a record in the last three screens. Unauthorized or unknown IDs do not expose another facility's evidence.

## Choose the exercise mode

- **Standalone simulation:** uses the same seeded `SimulationEngine` through `SimulationLabRepository`. **Advance 1 hour** progresses generated lifecycle events; the offline exercise shows cached records read-only. Model, seed, exercise clock and simulation labels remain visible. This mode cannot submit intake, attest results or create corrections. Use `SIMULATION_DAY=0` to start before generated sampling, or the default day `10` to inspect existing evidence.
- **Supabase:** use the [shared client configuration](development.md#configuration), rebuild Portal and sign in at `/#/lab`. The connected Lab reads the same facility records as Field and Verify. Every write requires a server response. The seeded backend remains a labeled simulation even when a real Auth account submits a command.

## Provision an authorized reviewer

Create and confirm a local email/password Auth account using Studio, as described in [Local Supabase](development.md#local-supabase). In the trusted SQL editor, assign that account to an explicit facility:

```sql
insert into public.memberships
  (user_id, organization_id, facility_id, role, is_simulated)
select '<REVIEWER_AUTH_USER_UUID>'::uuid, organization_id, id, 'lab', is_simulated
from public.facilities
where id = '<FACILITY_UUID>'::uuid;
```

The facility picker contains only the reviewer's active, unexpired `lab` assignments. A `field`, `manager` or organization-wide `admin` membership alone does not confer reviewer authority. Memberships are checked again for commands, including receipt retries; revocation or expiry removes access. The client cannot write the reviewer identity or review timestamp. Keep privileged provisioning credentials outside the app.

## Register and receive a sample

Sample capture uses the existing Field-side `register_sample` RPC. The current Field UI does not expose a registration form. An authenticated Field SDK client with a matching facility assignment can register one as follows:

```dart
final resultId = await fieldClient.rpc('register_sample', params: {
  'p_point_id': point.id,
  'p_collected_at': collectedAt.toUtc().toIso8601String(),
  'p_method': 'Membrane filtration (simulation)',
  'p_preservation_note': 'SIMULATED transport record. No physical water sample.',
  'p_sample_id': const Uuid().v4(),
});
```

For a generated exercise, choose `collectedAt` from the facility's canonical simulated clock, available as `asOf` on its Field/Lab snapshot. The RPC returns the initial **result** ID; its sample ID is separate. The authenticated SDK integration test in `packages/data/test/lab_supabase_integration_test.dart` supplies a runnable example.

Refresh Lab, select the sample in **Inbox** or **Sample intake**, record the custody handoff, and accept or reject it with a reason. Receiving a collected sample and recording its intake decision are one transaction. Custody retains the collector, receiving reviewer, timestamp and note. Rejected samples remain visible with **No valid result from this sample.** They cannot become negative results or satisfy verification.

## Enter, attest and correct

1. In **Results**, choose an accepted sample. Retain its planned method and select the exact indicator, units, reported value and detection limit. Supported units are CFU/100 mL, MPN/100 mL and presence/absence. Presence/absence accepts `0` or `1`; H₂S uses screening presence/absence. Count values and limits are not rounded or converted.
2. Submit the result with an entry note. A server receipt confirms entry only; authorized review is still pending.
3. Review the identity, method, units, detection limit and signed report. Provide the report reference, review reason and confirmation, then **Attest result**. The server records the authenticated reviewer and authoritative timestamp. Publication remains a separate authorized manager transition.
4. In **Revisions**, inspect the complete preserved lineage and attest a corrected value and detection limit with a signed report and correction reason. Sample, point, indicator, method and units stay fixed. The server supersedes the earlier result and creates a new reviewed record, retaining the original measurement, report, reviewer and timestamps. The new revision needs its own publication decision.

Signed report references must be HTTPS URLs for an authorized document service. `simulation://` references are accepted only for simulated records. This slice records and copies a supplied reference; document upload, hosting, signature validation and download authorization belong to the document service. A URL alone is not scientific verification: attestation records the authorized reviewer's review of the linked report.

The UI preserves the [status-language contract](safety/status-language.md), including `Simulated lab review`, source/stage distinctions, and the limitation that a test describes one sample, at one point, at one time.

## Refresh, offline and uncertain outcomes

All four screens implement skeleton loading with the shared `FrostedSkeleton`, empty, error, permission-denied, offline, stale and success states. Reduced-motion preferences disable skeleton animation.

- A snapshot becomes stale after five minutes of actual read time. This is a workspace refresh policy, separate from sample currentness. Collection, receipt, testing, review, publication and simulation-clock timestamps remain distinct.
- During a refresh or connection failure, mounted forms retain their in-tab drafts read-only. A changed server version requires explicit review/reset before resubmission. Drafts are not persisted across page reloads, screen changes, facility switches or sign-out.
- Actions do not optimistically change evidence or display success. An unconfirmed action retains its event UUID and exact payload in memory. Reconnect, refresh and choose **Retry unconfirmed action** to obtain the original receipt, including when the record has already advanced. Resolve it before leaving the session or facility.
- Session changes and permission failures discard private cached records and pending commands. Requests from an older session cannot populate or unlock a newer session.

## Server and test contracts

`supabase/migrations/202611050005_lab_workspace.sql` adds the lab-scoped snapshot and idempotent `lab_command` RPC. It extends the existing lifecycle commands and immutable-evidence triggers. Intake, result entry, attestation, corrections, audit and command receipts use the same transaction boundary; clients retain no generic table write privilege.

- `apps/portal_web/test/lab/lab_screen_states_test.dart`: one seven-state group for each of the four screens.
- Other `apps/portal_web/test/lab/` tests: form validation, custody/rejection, unconfirmed-action retry, cross-session races, preserved drafts, version changes, 320/1440 px routes at 130% text and reduced motion.
- `packages/data/test/lab_repository_test.dart`: generated provenance, read-only playback and ancestry ordering with equal simulated timestamps.
- `supabase/tests/lab_workspace.test.sql`: real database roles/JWT claims, facility/tenant isolation, unauthorized/revoked/expired reviewers, rollback, receipt replay, rejected verification, report guards and immutable corrections.
- `packages/data/test/lab_supabase_integration_test.dart`: Auth and PostgREST journey through sample registration, intake, measurement, attestation, two corrections, replay and denial after sign-out.

Run the opt-in SDK journey with the separate Field/Lab accounts described in [development checks](development.md#sdk-integration-tests). CI provisions both accounts in a disposable backend.
