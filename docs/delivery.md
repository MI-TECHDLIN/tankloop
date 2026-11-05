# Delivery scope

## Runnable now

Field has Today, the facility's water network, read-only case history, device activity, profile/exercise controls and the versioned inspection flow. The flow supports incomplete drafts, required/unknown answers, autosave, explicit save, offline queue, retry, durable receipt, blocked conflict state and account-scoped cache recovery.

Verify has a public token-entry/root route, water-point identity, dated status/evidence, open concerns, published test history, stale/missing/error states, a text-first view and deterministic date controls in simulation mode.

Lab has Inbox, Sample intake, Results and Revisions in the same Portal app. It supports scoped reviewer sign-in, facility selection, accept/reject with custody and reason, exact measurements/detection limits, server-only attestation and immutable superseding corrections. All four screens have seven-state widget coverage and use the shared design-system skeleton. See the [Lab workflow guide](lab-portal.md).

The backend has tenant/facility RLS, constrained lifecycle commands, sample custody, lab correction lineage, work approvals, verification plans, post-action closure guards, escalation, QR revocation and audit. The simulator traverses the whole registry -> inspection -> sample -> reviewed result -> incident -> work -> follow-up -> public-record path.

## Deferred interfaces and integrations

- Connected manager triage/assignment/approval workspace; the standalone manager simulation is available. The corresponding RPCs and domain rules are implemented.
- Registry authoring, Field multi-facility selection, invitation/permission management and template administration. A trusted operator provisions these records for now.
- Camera QR scanning, printed QR generation, photos, attachment upload and signed report downloads. The public QR destination and copyable opaque links work.
- Resident concern submission, consent/moderation workflows, push/SMS/email delivery and externally acknowledged escalation.
- Conflict-resolution editor, automatic/background synchronization, encrypted local storage and cold offline web installation. Blocked drafts remain retained for explicit review.
- Organization reports/exports, maps beyond the illustrated topology, remaining blueprint screens, Pidgin/local-language validation and full keyboard/screen-reader evaluation.
- Hosted provisioning/deployment, signed Android distribution, real lab/pilot ingestion and expert approval of operational policies.

## Validation record

Local checks include pure-Dart lifecycle/simulation tests, actual SQLite reopen/lost-ACK tests, Field widget draft/recreation/queue/sync tests, Portal state/routing/responsive widget tests, analysis, web builds, Android debug build, migration/seed application, and 232 pgTAP trust-boundary assertions. Separate local Auth accounts exercise Field submission/public projection and the complete Lab intake, rejection, attestation, correction and idempotent-retry journey through the Dart Supabase repositories.

The app-level checks found and corrected startup date-locale initialization, a retry callback, narrow header layout, Material ink rendering and inconsistent seeded clocks between the connected clients. The database checks caught an old observation uploaded after repair incorrectly satisfying follow-up; closure now checks both observation and receipt times.

**Browser verification: not run.** The authorized `chrome-devtools-axi` session reset/retry still failed with `BRIDGE_NOT_READY`. Widget layout/interaction checks and successful web compilation are recorded separately; neither is a browser visual review. Firstmate authorized completing this slice with that limitation.

## Next delivery steps

- **Field and reliability:** Android/device walkthroughs, QR camera entry, offline restart/reconnect, attachment capture and conflict recovery.
- **Backend and evidence:** hosted Supabase, connected manager workflows, account provisioning, document-service integration and institution-specific verification policy review.
- **Public experience and entry:** public comprehension/accessibility, deployment, demo narrative/video and challenge submission.

Integrate around a single shared simulated tenant and keep source/provenance labels visible throughout the demo. Publish the competition entry **before 2026-11-20 21:00 UTC**; repository availability is not proof of an entry submission. The hosted URLs, publishable key, team accounts and final competition assets are captain-owned inputs for that next stage.
