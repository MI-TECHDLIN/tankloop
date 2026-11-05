# Field Android setup and verification

Use Flutter **3.47.9** (the CI version), Android SDK, and Java 21. The field
client has its own Android application ID: `org.tankloop.tankloop_field`.
Connect a low-end Android phone with developer options and USB debugging enabled,
and accept its debugging prompt. `flutter devices` must list the physical phone.

From the repository root:

```sh
flutter pub get --enforce-lockfile
(cd apps/field_app && flutter build apk --debug --no-pub)
adb -s <device-id> install -r apps/field_app/build/app/outputs/flutter-apk/app-debug.apk
adb -s <device-id> shell am start -n org.tankloop.tankloop_field/.MainActivity
```

The default build uses the seeded simulation, with visible simulated-data labels.
It evolves from the domain simulator, including submitted observations, receipts,
work steps, and the simulated clock. It is not real laboratory or pilot evidence.
For an authenticated backend build, use the environment definitions documented
in `docs/development.md`; migrations through `202611050007_field_receipts.sql`
must be applied to that disposable environment first. Sign in and load assignments
while connected before taking that phone offline. Never include a service-role key.

On a second display, open Water, choose the same point, and use **Show QR label**.
Print or display that generated label for the physical point. The QR contains the
public point link and the label includes its opaque code for manual entry. The
scanner accepts the code, a public `/point/<code>` link, or the web hash-route link.
It checks live revocation before opening the point's assigned checks and history.
An offline phone can open downloaded tasks from Today or Water; it cannot establish
that a QR is still active. A revoked or unknown code never opens an assignment.
If camera access is denied, enter the printed code manually or restore camera
permission in Android settings. The scanner uses the bundled Android barcode model.

## Physical-phone acceptance checks

These are device verification steps, not a presentation script:

- In airplane mode, answer an inspection, attach a camera photo to a checklist
  answer, and queue it. The phone must show **Pending sync**, never a receipt.
- Force-stop and reopen the app. Answers, notes, image previews, photo-to-answer
  links, and the queued event must still exist. Clear the camera cache separately;
  captured photos are retained in the app's Drift database.
- Reconnect. Foreground sync runs every 30 seconds and on app resume; **Sync now**
  retries immediately. Confirm a server receipt, then refresh the assignment.
  Repeated taps must produce one submission and one incident at most.
- Interrupt an upload, restart, and reconnect. Completed photo uploads are resumed
  by stable object ID; a lost upload or command receipt cannot duplicate evidence.
- Deny camera access and confirm the manual QR path still works. Revoke a QR from
  the authorized management surface and verify that scanning the old label fails.
- With **Don't keep activities** enabled, open the camera and return. The pending
  destination is saved before Android leaves the app; lost camera results are
  recovered for that original draft on startup/resume.
- Record an assigned work-order step with notes/photos offline. Reconnect and
  confirm its receipt. The next step uses the newly acknowledged version.
  Completion does not resolve the incident or accept the repair for the manager.
- Use a second scoped account and confirm it cannot see the first account's
  drafts/photos. **Sign out and clear device** removes that account's local queue,
  images, and dashboard. Server-acknowledged records remain.

Record the phone model, Android version, RAM, APK commit, steps exercised, and
observed results before declaring physical validation complete. Automated tests
and an APK build do not establish low-end phone behavior. No physical Android
phone was attached during this implementation session; physical validation remains
an explicit delivery gate.

## Persistence and failure behavior

Android uses Drift/SQLite for drafts, immutable queued commands, photo bytes and
metadata, upload checkpoints, and receipts. Photos are persisted before attaching
them to a saved draft. The camera's temporary path is not the durable source.
Account and facility namespaces prevent accidental cache mixing. Android backup
is disabled; device storage still relies on the OS application sandbox.

The server receives `client_event_id`, expected aggregate version, device-observed
time, and uploaded evidence references. The server validates membership, assignee,
version, checklist question, private object existence, and unchanged command content.
It acknowledges the observation and attachment links in one transaction. Photo
objects cannot be overwritten; uploads interrupted before their local checkpoint
retry the same object identity. Private Storage access is limited to the owner or
members authorized to review the linked facility evidence. Public QR responses
never contain photo paths or private notes.

Pending work, transient sync failure, and conflicts/permission failures are distinct.
Transient failures preserve the queue and can retry; blocked commands retain the
original evidence for explicit review. Device clock skew does not replace server
receipt times. Draft writes and enqueue operations serialize to protect double taps.
Clearing device data invalidates in-flight sync so it cannot recreate the cleared queue.

## Automated coverage

`apps/field_app/test/screen_states_test.dart` pumps nine real field screens in all
seven states: skeleton loading, empty, error, permission denied, offline, stale,
and success. `field_flow_test.dart` exercises navigation, saved answers, photo
cache loss, recreation, queueing and receipt display. `packages/offline_sync/test/`
uses real Drift close/reopen tests, including a power loss between remote photo
commit and local checkpoint, plus airplane mode, partial uploads, lost receipts,
clock skew, duplicate taps and revoked QR handling. `supabase/tests/field_evidence.test.sql`
checks scoped attachment access, idempotency, atomic rollback and work-step receipts.
The browser preview uses origin-local preferences and is not the Android durability
acceptance target.
