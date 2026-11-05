# Implementation architecture

These notes describe the runnable first slice. The wider product design and diagrams are in [architecture.md](architecture.md).

## Package boundaries

`domain` is pure Dart: stable IDs/scopes, immutable evidence, independent lifecycle guards, public projection and the discrete-event simulator. It imports neither Flutter nor Supabase. `data` provides the common repository interface and the simulation/Supabase implementations. The Flutter apps compose these with `offline_sync`, `shared_forms`, `design_system` and `localization`.

Riverpod supplies the initialized Field runtime; GoRouter owns app routes. The form renders the issued checklist version rather than a hardcoded screen. The theme uses navy `#102A43`, teal `#0F766E`, mint `#EDF6F5`, canvas `#F6F8FA` and caution `#FFF0DF`, a 4-point rhythm, large rounded translucent cards and 48dp-class controls. Artwork is original vector work. Private inspiration material is not a runtime asset.

## Separate lifecycles

```text
Result:     collected -> received -> valid -> tested -> reviewed -> published
            received -> rejected; reviewed/published -> superseded + new revision

Work order: proposed -> approval_pending -> assigned -> in_progress -> completed
            completed -> accepted OR rework -> in_progress

Incident:   reported -> triaged -> assigned -> mitigation -> verification_pending -> resolved
            assigned may go directly to verification_pending with the required evidence
            verification_pending/resolved -> reopened -> triaged
```

Transition methods enforce scope, actor role, active membership, authoritative receipt, reason and chronological audit. SQL independently enforces the trusted boundary; client-side domain checks are not authorization.

- Only an authorized lab reviewer with a linked report can attest a result. A rejected sample is terminal and cannot satisfy follow-up.
- A correction creates a new revision, supersedes the original and retains reason, actor and time. Reviewed evidence is not silently overwritten.
- Work needs approval, an active assigned worker and completion evidence. Acceptance does not resolve the incident.
- Resolution needs a configured nonempty plan, accepted work, reviewed controls/notices, matching post-action checklists and/or qualifying reviewed samples, and a communication reference.
- Follow-up is checked against scope, point, method, indicator, freshness and simulation provenance. A pre-repair observation uploaded after repair cannot pass the checklist cutoff.
- Escalation is a separately audited event on an active critical/overdue incident. It does not claim that an external authority was contacted.
- Reopening retains the earlier closure trail and requires repeat verified finding, new evidence or invalidated verification.

The authoritative implementations are `packages/domain/lib/src/{results,work_orders,incidents}.dart` and `supabase/migrations/202611050002_commands.sql`. The [Lab portal](lab-portal.md) extends those commands with a lab-scoped snapshot, atomic intake and idempotent receipts in `supabase/migrations/202611050005_lab_workspace.sql`.

## Tenant and public boundaries

The hierarchy is organization -> facility -> water system -> assets -> sampling points. Composite foreign keys prevent cross-facility relationships; an additional trigger validates every affected point in an incident array. Simulation-label triggers prevent synthetic rows being relabeled within a facility.

All core tables have RLS. Authenticated reads require active, unexpired facility membership (or organization-wide admin membership). Client roles have no generic table writes. Scoped `SECURITY DEFINER` RPCs fix their search path, derive the actor from `auth.uid()`, verify roles and expected versions, and commit mutations and audit together. There are no service-role credentials in either application.

The anonymous read boundary returns only point/facility labels, state wording, dated published tests and open concerns. `lookup_public_point` adds an explicit `found`/`missing`/`revoked` envelope and a point-scoped pending-review flag; `lookup_public_record` retains its original null-for-unavailable contract. Both omit staff/reporter identity, visit notes, internal IDs, report references, raw attachments and coordinates. A token's point identity cannot be changed or unrevoked.

`submit_public_concern` accepts private resident input, derives scope and provenance from the printed token, and atomically records an unverified incident, audit and idempotent receipt. Contact requires consent; private reads require manager/admin membership. Point-wide throttling uses actual server time, even for simulated records. Verify uses a separate sessionless client, so staff sign-in cannot leak into public scans. See [public Verify and sticker generation](public-verify.md).

Public projection priorities are open confirmed findings, authorized corrective work, inspection observations, other open concerns, current reviewed evidence, then missing current evidence. An old normal test never hides an open concern. The initial demonstration freshness window is 30 days; up to 20 published test records are shown. These are explicit demo policies, not an institution's approved monitoring schedule.

## Offline and sync

The durable outbox below belongs to Field. Lab retains read-only snapshots and in-tab drafts during refresh failures; its attestation and correction commands require a connected server. An uncertain lab action can retry the same in-memory event ID for its original receipt. Lab has no durable offline command queue.

Verify retains only an in-page snapshot during refresh failures. Its concern form has no durable save or upload queue; an unchanged retry checks the same receipt identity. Standalone simulated concerns last only for the open point session. Text-first mode reduces rendering effects but still downloads Flutter.

```text
Form -> atomic local draft -> immutable queued command -> scoped RPC
                                                    <- durable receipt
```

- Native storage uses a versioned Drift/SQLite key-value table with transactional snapshots. Browser storage uses SharedPreferences asynchronous local storage, with the draft and its queue state in one JSON value.
- The outbox is namespaced by backend/identity, actor, organization and facility. Dashboard caches are backend/account scoped. A known permission failure clears cached assignments and stops submission; a network failure may show explicitly stale assignments.
- Writes finish before the UI displays "saved". Restart restores the command UUID, issued template, answers, notes, observed time, attempts and receipt.
- A retry uses the same UUID and identical payload. The server returns the original receipt, even after a lost acknowledgement. Reusing a UUID for changed content conflicts.
- Permission/version/validation failures retain a blocked record for explicit review; transient failures retain a pending record with bounded exponential backoff and jitter. **Sync now** is a foreground retry that intentionally bypasses the delay. There is no background OS scheduler in this slice.
- `observed_at` is the device observation time; `received_at` is authoritative server time. A simulated facility uses its trusted exercise clock. Membership expiry always uses real time.
- The local simulator reconstructs acknowledged user commands and its saved clock on restart. Independent simulation app instances do not share those commands.

Browser persistence survives normal reloads after the application has loaded. It does not promise a cold offline web launch, unlimited storage, or survival after browser data is cleared. Offline install/startup, encrypted local storage, attachments and conflict-resolution UI are deferred.

## Validation boundaries

Pure-Dart tests cover the three lifecycles, corrections, public wording, scope/freshness, seeded replay and time progression. Offline tests include actual SQLite close/reopen, lost acknowledgement, permission/conflict retention and failed persistence. Widget tests exercise the complete draft/recreate/queue/sync path and public-record states at phone and desktop widths. pgTAP checks the database trust boundaries independently; an opt-in real SDK integration crosses Auth, PostgREST and the anonymous projection.
