# Development

## Toolchain

- Flutter 3.47.9 / Dart 3.13.7, with Flutter web support.
- Supabase CLI 3.0.0 and Docker for backend work. `supabase/config.toml` targets PostgreSQL 17.
- Android SDK and JDK supported by Flutter for Android builds. Run `flutter doctor` for the device-specific setup.

The Dart workspace has one root `pubspec.lock`. Run `flutter pub get` at the root after changing dependencies.

## Configuration

Copy `.env.example` to ignored `.env` and pass its absolute path with `--dart-define-from-file`. Flutter compiles these client values into the application; it does not read process environment variables at runtime.

```sh
cp .env.example .env
```

From either app directory:

```sh
flutter run -d web-server --web-port 8080 --dart-define-from-file=/absolute/path/to/tankloop/.env
```

Use port `8081` for Portal (Verify, Manage and Lab). Available defines:

| Define | Default / purpose |
| --- | --- |
| `TANKLOOP_MODE` | `supabase` only in Field (the default); Portal retains `simulation` or `supabase` |
| `SIMULATION_SEED` | Portal only: `20261101` |
| `SIMULATION_DAY` | Portal only: `10`, allowed range `0..365` |
| `SUPABASE_URL` | Always required by Field; required in Portal Supabase mode |
| `SUPABASE_ANON_KEY` | Client-safe publishable or legacy anon key only |
| `PORTAL_BASE_URL` | `http://localhost:8081`; used by copied public point links |

Never put a service-role key, `sb_secret_` key, database password, Auth password or access token in a Flutter define, source file or commit. The public repository excludes local configuration, signing keys, build output, blueprint PDFs and inspiration assets.

## Local Supabase

At the repository root:

```sh
supabase start
supabase test db
```

Startup applies the repository migrations and generated seed. `supabase status` shows the local API URL and client-safe key for `.env`. Set `TANKLOOP_MODE=supabase`, then rebuild both apps with that file. The anonymous Portal and authenticated Manage/Lab use the same URL/key as Field.

`supabase db reset` reapplies migrations and seed to a **fresh local database**, replacing local records and Auth users. Use it when intentionally resetting the exercise. The seeded database has a fixed simulated clock used by Portal exercise records. Field uses the current clock and excludes synthetic records, even when membership belongs to a seeded facility. Membership expiry uses actual server time.

### Create a usable Field account

The synthetic seed actors have no passwords or sessions. Use local Studio at `http://127.0.0.1:54323` to create and confirm your own email/password Auth user. In its SQL editor, provision a field membership, substituting the created user's UUID:

```sql
insert into public.memberships
  (user_id, organization_id, facility_id, role, is_simulated)
select '<YOUR_AUTH_USER_UUID>'::uuid, organization_id, id, 'field', is_simulated
from public.facilities
order by id
limit 1;
```

Sign in to Field with that account. This slice loads the first authorized facility by ID; a multi-facility switcher is deferred. The seed contains no real observations, so Field shows empty assignment and history states until non-synthetic records exist. Do not relabel seed rows to populate Field. A specifically assigned inspection is also checked against its assigned inspector by the server.

Use **Water > Copy public QR link** to open the exact point in Verify. A `Yes` risk answer creates an inspection-sourced concern when the command is accepted. Refresh that public point to see it. A concern does not create a laboratory result.

On an Android emulator, use `http://10.0.2.2:54321` for the local API and a reachable Portal URL. The Android app allows local development traffic. Hosted builds should use HTTPS.

### Public Verify and printable QR stickers

See [public Verify](public-verify.md) for phone-reachable demo hosting, A4 sticker regeneration, text-first/print/share controls, private anonymous concern reporting and session-only limitations.

### Laboratory workspace

Open `/#/lab` on the Portal origin. Follow the [Lab workflow guide](lab-portal.md) for reviewer provisioning, sample registration, custody, results, report references, immutable corrections and retry behavior. Standalone simulation is read-only playback; commands require the connected backend and a scoped laboratory reviewer.

### Manager workspace

Open `/#/manager` on the Portal origin. Standalone mode projects the shared seeded simulation engine and labels every record/action as simulated. **Settings > Offline exercise** keeps the fetched records visible while pausing actions; reconnect to refresh.

For connected mode, apply all migrations including `202611050011_manager_workspace.sql`. Create and confirm a separate local Auth account in Studio, then provision its scoped membership using the same trusted SQL editor as Field:

```sql
insert into public.memberships
  (user_id, organization_id, facility_id, role, is_simulated)
select '<YOUR_MANAGER_AUTH_USER_UUID>'::uuid, organization_id, id, 'manager', is_simulated
from public.facilities
order by id
limit 1;
```

Sign in on the manager route and choose an authorized facility. Facilities exposes asset ancestry, downstream points and QR identities; Inspections shows issued checklists and submitted evidence; Samples & Results preserves exact measurements, custody and revision history; Team shows scoped grants, assignments and actor audit history. Team access is read-only; a trusted administrator provisions and changes memberships.

Incident triage/assignment, interim measures, verification requests, internal escalation, work approval/acceptance, reviewed-result publication and QR revocation require an audit reason and the current snapshot. Saving a verification plan and requesting verification are separate commands; the UI reports a saved plan if the transition fails and requires a refresh. Publication preserves the laboratory reviewer's attestation.

After five minutes or a version conflict, the workspace becomes read-only until refreshed. Network failures retain only the in-memory fetched snapshot; privileged actions are never queued. A facility/account change or permission failure discards the workspace. The screen freshness window uses actual fetch time and does not represent sample validity or advance the simulation clock.

### SDK integration tests

The opt-in integration tests use actual Auth and PostgREST endpoints with client-safe credentials. Field submits an inspection, retries its receipt and checks the anonymous public projection. Lab registers samples through a Field account, receives/rejects them through a separate Lab account, enters a result, attests a linked report and verifies immutable corrections and receipt replay. These mutation tests accept only a localhost API and a simulated facility.

Export these values locally without committing them:

```sh
export TANKLOOP_TEST_URL=http://127.0.0.1:54321
export TANKLOOP_TEST_ANON_KEY='<LOCAL_ANON_KEY>'
export TANKLOOP_TEST_EMAIL='<YOUR_LOCAL_AUTH_EMAIL>'
export TANKLOOP_TEST_PASSWORD='<YOUR_LOCAL_AUTH_PASSWORD>'
export TANKLOOP_TEST_LAB_EMAIL='<YOUR_LOCAL_REVIEWER_EMAIL>'
export TANKLOOP_TEST_LAB_PASSWORD='<YOUR_LOCAL_REVIEWER_PASSWORD>'
(cd packages/data && dart test --reporter expanded)
```

The Field fixture needs the membership above and an unsubmitted inspection. The SDK integration explicitly retains labeled synthetic fixtures and also checks that the production Field projection is empty. Each successful SDK run consumes one scheduled inspection; reset the disposable database or choose another fixture when exhausted. The Lab account needs an active `lab` membership in the same facility and creates fresh samples per run. CI creates separate accounts and a fresh database for every run. Each integration test is explicitly skipped when its required environment is absent.

## Checks and builds

From the repository root:

```sh
dart format --output=none --set-exit-if-changed apps packages
flutter analyze --no-pub
(cd packages/domain && dart test --reporter expanded)
(cd packages/data && dart test --reporter expanded)
(cd packages/offline_sync && flutter test --no-pub --reporter expanded)
(cd apps/field_app && flutter test --no-pub --reporter expanded)
(cd apps/portal_web && flutter test --no-pub --reporter expanded)
supabase test db
```

```sh
(cd apps/field_app && flutter build web --release --no-pub)
(cd apps/portal_web && flutter build web --release --no-pub)
(cd apps/field_app && flutter build apk --debug --no-pub)
```

Pass `--dart-define-from-file=/absolute/path/to/.env` when building Supabase mode. Serve each app's `build/web` directory with a static HTTP server. Portal routes include `/#/point/<opaque-token>`, `/#/manager` and `/#/lab`; hash routing does not need path rewrites. A deployed subdirectory also needs Flutter's `--base-href=/subdirectory/`.

`.github/workflows/ci.yml` runs formatting, analysis, domain/offline/widget tests, both release web builds, an Android debug build, migration/seed application, pgTAP and the authenticated Field/Lab SDK integrations.

## Hosted inputs

The captain must provide a dedicated Supabase project reference, project URL, **publishable/anon key**, and the Field/Verify hosting URLs. A trusted operator needs project access to apply migrations, load the simulated seed into an empty demo project, and provision team accounts and their memberships. Database credentials stay in the operator's environment.

1. Link the intended project and apply migrations with `supabase db push --remote`. Supabase CLI v3 targets the local database unless `--remote` is explicit.
2. For a dedicated empty demonstration project, load `supabase/seed.sql` through its trusted SQL connection. This creates synthetic Auth identities as well as tenant data. Do not apply it over an existing dataset.
3. Provision separate real Auth accounts for the team and scoped `field`, `manager` or `lab` memberships. Seed actors cannot sign in.
4. Configure the Auth site/redirect URLs for the hosted Field origin, build both clients with the project URL/client-safe key, and set Field's `PORTAL_BASE_URL` to hosted Verify.
5. Deploy the two `build/web` directories to HTTPS static hosting. Issue or print point links using their opaque tokens. Keep the simulated labeling visible.

Client-side **Advance 1 day** progresses standalone simulation only. Advancing a shared hosted exercise requires a new generated snapshot in a disposable demo database; no privileged clock-changing endpoint is exposed to clients.
