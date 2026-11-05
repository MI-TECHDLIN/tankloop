# Public QR records and physical demo stickers

TankLoop Verify opens `/#/point/<opaque-token>` without a sign-in. It shows the point nickname, facility, exact [status wording](safety/status-language.md), published sample history, method, indicator, reported value and detection limit, four separate evidence timestamps, freshness and every open concern. A current sample is not continuing water-quality assurance. Generated records retain the full simulation banner.

## Run the physical demonstration

From `apps/portal_web`, start the standalone simulator on an address reachable by the phone:

```sh
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081
```

Use the computer's LAN address, such as `http://192.168.1.25:8081/`, on a phone connected to that network. Substitute the actual address in the generator command below. `localhost` on the phone means the phone itself. A hosted HTTPS Portal URL also works; a hosting subdirectory needs the matching Flutter `--base-href`.

From the repository root, generate the self-contained HTML sheet:

```sh
dart run apps/portal_web/tool/qr_stickers.dart \
  --base-url http://192.168.1.25:8081/ \
  --seed 20261101 \
  --day 10 \
  --output /absolute/path/to/tankloop-qr-stickers.html
```

Open that file in a browser and choose **Print A4 / save PDF**. Print on **A4, portrait, 100% scale**, with browser headers and footers off. The sheet uses 10 mm page margins and six 93 x 80 mm cut-out stickers per page. Each sticker includes:

- A 38 mm black vector QR with a four-module white quiet zone.
- The simulator's point nickname and facility label.
- `Scan to see this water point's latest checked record`
- A visible, outlined `SIMULATED DEMO` label that does not depend on printing background colors.

The generator derives tokens, names and model metadata from `SimulationEngine`; its seed and day reproduce the same baseline at every scan. It makes no external QR/image-service request. Overlong URLs that would make the printed modules too small are rejected. `--facility-index 0` limits the output to one generated facility; omit it for all points. `--help` lists all options. Generated sheets can stay outside the checkout; the generator and tests are committed.

Before attaching labels, open the exact phone-reachable destination and match each nickname to the physical demonstration point. A QR scan and a printed record are not physical water tests.

### Shared Supabase demonstration

Use the [local or hosted backend setup](development.md) and rebuild Portal with `TANKLOOP_MODE=supabase`. Generate with the same seed used to create that database and add `--mode supabase`:

```sh
dart run apps/portal_web/tool/qr_stickers.dart \
  --base-url https://YOUR-VERIFY-HOST/ \
  --seed 20261101 --day 10 --mode supabase \
  --output /absolute/path/to/tankloop-qr-stickers.html
```

Connected links omit client seed/day overrides; the database owns the exercise clock. The generator is simulator tooling, not a live database export: seed, day and issued labels must match the intended demo database. Recreating a sheet from a seed does not reactivate a revoked server label. Provision its replacement before printing. Real issuance uses unpredictable server-generated tokens rather than reproducible demo tokens.

## Public controls and recovery

- **Text-first view** removes artwork, frosted blur, shadows and animated loading decoration. Shared links retain `view=text` inside the hash route. Flutter's initial download is still required; this is not a separate small HTML client or a cold-offline viewer.
- **Share link** copies only the public token route and applicable exercise/view parameters. It strips unrelated query parameters and credentials.
- **Print view** opens a self-contained HTML snapshot, with a print/save-PDF button. Status, simulation disclosure, limitations, timestamps, historical tests and open concerns remain visible. Refresh the public link for later updates.
- Loading uses the shared design-system skeleton and respects reduced motion. Missing, revoked, service-error, permission-denied and offline outcomes make no water-quality claim. An expired sample remains historical, even beside an open confirmed concern.
- A failed refresh or five-minute-old page becomes an explicitly labeled last-loaded snapshot; concern submission is disabled until refresh. Previously loaded concerns remain visible. Revocation or denied access clears the displayed record. Nothing is durably cached by Verify.

## Resident concerns and privacy

**Report a concern** defaults to anonymous. Category and a private description are required. Contact details appear only after explicit follow-up consent and remain optional. Neither the description nor contact details appear in public records, print views or sharing links.

In Supabase mode, `submit_public_concern` atomically stores private input, creates a `resident_report` incident and appends audit. The server derives tenant, facility, point, provenance and timestamps from the token. A receipt confirms database receipt, not verification or notification. Unchanged retries reuse the event ID, including after a lost receipt. The database allows five new reports per point per actual minute, including across multiple active labels; valid receipt replay does not consume that limit.

Private reports are readable only by active scoped managers or administrators through RLS. Other staff and anonymous clients cannot read contact details. A dedicated moderation/retention interface and external delivery remain deferred. Anonymous reporting does not perform laboratory review or contact a government office.

Standalone simulation uses guarded domain incidents in the open page's session. Its receipt explicitly says no facility or external service was contacted. Reloading or changing the exercise route clears these custom submissions. An unsent form holds text only while it stays open; it has no durable local save or upload queue. Offline or failed submissions never claim to have been saved or delivered.

## Implementation and checks

- `apps/portal_web/lib/public/`: page controller, major widgets, concern form, canonical link and print renderer.
- `packages/data/lib/src/public_point_{repository,supabase}.dart`: narrow public repository, simulated adapter and sessionless RPC adapter.
- `supabase/migrations/202611050010_public_verify.sql`: private report RLS, projection provenance joins, explicit missing/revoked lookup envelope and receipt/throttle transaction. `lookup_public_record` retains its legacy null-for-unavailable contract.
- `apps/portal_web/tool/qr_stickers.dart`: A4 generator; `qr` and `args` are development-only dependencies. `web` supplies supported, typed browser connectivity and printable-HTML interop.
- `apps/portal_web/test/public*`, `packages/data/test/public_point_repository_test.dart`, and `supabase/tests/public_verify.test.sql`: state, accessibility, precision, print, QR geometry, privacy, scope, consent, rollback and replay checks. The connected SDK journey in `packages/data/test/supabase_integration_test.dart` also submits and retries an anonymous concern.

Use the [standard check commands](development.md#checks-and-builds). Live-browser, physical print/phone-scan, assistive-technology and resident-comprehension checks remain separate from compilation and automated widget/SQL checks.
