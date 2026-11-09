# Prepare handover

Field staff can open a water point or expand a case, choose **Prepare handover**,
and prepare an editable draft from synced records. The screen explains what
happened, what is missing and what happens next, with dated source details.

The model is **`openai/gpt-oss-120b` on Groq**, pinned in
`supabase/functions/prepare-handover/core.ts`; prompt version `handover-v1`.
This is a bounded evidence-selection feature. Groq selects and orders up to six
facts from a server-built catalog. It does not author unchecked factual prose.
Every selected ID, citation and sentence must exactly match the catalog, including
dates, values, units, detection limits and evidence status. Missing information
and follow-up steps are deterministic and cannot be removed by the model.
An exact match establishes fidelity to a source, not whether the source is true.

Notes, names of people, contacts, attachments, report URLs and free-text task
descriptions are excluded from the provider input. Point labels are shown locally
but are not sent to Groq. A stored note saying to ignore instructions cannot
become a model instruction. This first release summarizes structured record
status, not the contents of narrative notes or laboratory reports.

## Authority and persistence

- The function verifies the bearer token using Supabase Auth, then passes that
  same JWT and the public anon key to `handover_snapshot`. No service-role key is
  used. Keep platform `verify_jwt = true` as an additional check.
- The RPC is `SECURITY INVOKER`, with existing RLS and an explicit active,
  unexpired field/manager/admin membership check. Lab-only and anonymous callers
  cannot prepare a staff handover. Missing and forbidden selections look alike.
- The caller supplies only a point or incident UUID, never source records or an
  organization-wide query. Related records are restricted to the selected
  facility and point assets (or the incident's points). At most eight of each of
  six source kinds are returned. Full counts disclose truncated history. The
  assistant never claims the bounded snapshot is a complete operational history.
- Simulated records are excluded. Production does not silently fall back to
  generated evidence. An empty selection produces `no_records`, without a model
  call or an inference about water quality.
- Full-row source hashes, source versions and counts are included in the snapshot
  fingerprint. The function rechecks access and sources after Groq responds and
  before a reviewed save. Changed sources or drafts older than 30 minutes require
  regeneration and another review. Notes can invalidate the hash despite being
  excluded from the provider input.
- **Save reviewed draft on device** requires an explicit review checkbox and an
  online source recheck. Editing resets the checkbox. The save records the
  original snapshot, input fact catalog, model/prompt version, generation time,
  original AI selection, human wording, verified reviewer ID and review time.
  Drafts are private device data, namespaced by backend/account/facility/selection.
  Clearing device data removes them. They are not synced to a shared workspace.
- Existing reviewed drafts can be opened and edited offline, with freshness
  explicitly unverified. Generation and saving are unavailable offline. Failed
  requests retain the editor and the last saved draft. Unsaved edits remain in
  memory only; leaving the screen or closing the app discards them. A replacement
  draft retains the previous wording on screen for reference.
- There is no publish, share, result attestation, incident mutation, autonomous
  tool use or treatment-advice operation. Existing incident transitions and
  inspection/work outboxes remain authoritative. Human edits are labeled as
  human wording and are not claimed to have passed the model's fact validation.

## Configure the server

The hosted project and remote deployment are separate operational work. This
change does not create a project or deploy remotely.

1. Apply `202611090001_handover_snapshot.sql` after existing migrations to the
   intended project. It adds a read-only RPC; it does not alter existing rows,
   roles, policies or transitions.
2. Store `GROQ_API_KEY` in Supabase function secrets. Use a dedicated private env
   file containing only that secret, excluded from git:

   ```sh
   supabase secrets set --project-ref <project-ref> --env-file /secure/tankloop-handover.env
   supabase functions deploy prepare-handover --project-ref <project-ref>
   ```

3. The runtime supplies `SUPABASE_URL` and `SUPABASE_ANON_KEY`. The function does
   not read `SUPABASE_SERVICE_ROLE_KEY`. Do not put the Groq key in Flutter
   defines, client `.env`, source, logs or screenshots.
4. Confirm the Groq project's model permission, request/token/spend limits and
   data-retention settings for the authorized records before enabling it for
   staff. Configure the desired project limits rather than relying on client UI
   throttling. The function never retries automatically, calls one pinned model,
   caps output at 2,048 tokens and times out the provider request at 20 seconds.
5. For an isolated local Supabase stack, use `supabase functions serve
   prepare-handover --env-file /secure/tankloop-handover.env`. Coordinate first
   when working on a shared stack; never reset its data for this feature.

The function returns stable error codes with plain messages: `not_configured`,
`no_records`, `unauthorized`, `forbidden`, `rate_limited`, `timeout`,
`stale_sources`, `review_required`, `invalid_output`, `invalid_sources` and
`unavailable`. A 429 asks the user to wait before a manual retry. Raw provider
responses, exception bodies and secrets are never returned or logged.

## Function contract

Authenticated POST to `/functions/v1/prepare-handover`:

```json
{"action":"generate","kind":"point","id":"<point-uuid>"}
```

Returns a versioned document with `model`, `prompt_version`, `actor_id`,
`generated_at`, `fingerprint`, `snapshot`, `input_facts`, `highlights`,
`next_steps`, `gaps`, `limitation` and `original_text`.

Before saving the reviewed text locally:

```json
{"action":"review","kind":"point","id":"<point-uuid>","fingerprint":"<sha256>","generated_at":"<server-timestamp>","reviewed":true}
```

Returns the authenticated `reviewer_id`, `reviewed_at` and matching fingerprint.
This is a source freshness receipt, not an attestation or cryptographic signature
of the human's wording. The server performs no persistence or domain mutation.

## Evaluation and reproduction

From the repository root:

```sh
deno fmt --check supabase/functions/prepare-handover
deno lint supabase/functions/prepare-handover
deno check supabase/functions/prepare-handover/index.ts
deno test --allow-net=127.0.0.1 supabase/functions/prepare-handover
flutter analyze --no-pub
```

Run `flutter test --no-pub` from `apps/field_app`, and `supabase test db` against
an authorized local stack. Database fixtures live only in rolled-back test
transactions. They do not establish measured-water evidence.

The additional Field SDK transport test launches a localhost Deno function and
uses real HTTP for the app SDK, function and explicit Auth/database/Groq doubles:

```sh
TANKLOOP_DENO_BIN=/absolute/path/to/deno \
TANKLOOP_HANDOVER_TEST_SERVER=/absolute/repo/supabase/functions/prepare-handover/test_server.ts \
flutter test --no-pub test/handover_endpoint_test.dart
```

CI runs that test separately with Deno 2.5.6. It covers actual SDK request/response
handling, human review, saved provenance, stale-source rejection and invalid
authentication. It is not a real Groq or Supabase Auth integration test.

The fixed synthetic suite also covers cross-tenant and cross-facility RLS,
expired/revoked membership, lab-only role rejection, source changes without a
version bump, bounded history, missing owners, rejected/superseded status,
malicious note/label instructions, altered IDs/dates/values/citations, provider
timeouts/429s/failures, no records, missing config, and review reset after edits.
Widget tests exercise source inspection, editing, review/save and a 320px screen
at 200% text. Existing offline inspection/work workflows remain regression-tested.

Real Groq requests, real account-to-provider end-to-end verification, model
comparison, latency/cost measurements and human comprehension/time-saving studies
must be reported separately from doubles. Do not infer those results from the
passing deterministic suite. No production readiness or water-safety claim is
made by this feature.

## Official documentation consulted

Reviewed 2026-11-09: [Groq structured outputs](https://console.groq.com/docs/structured-outputs)
lists strict-schema support for the chosen model, required fields and closed
objects; [Groq models](https://console.groq.com/docs/models) lists its model ID.
[Supabase function security](https://supabase.com/docs/guides/functions/auth) and
[Auth integration](https://supabase.com/docs/guides/functions/auth-legacy-jwt)
describe bearer verification and caller-scoped data access.
[Supabase secrets](https://supabase.com/docs/guides/functions/secrets) documents
server environment secrets. Schema conformance alone is not factual validation;
the catalog equality checks are TankLoop's additional boundary.
