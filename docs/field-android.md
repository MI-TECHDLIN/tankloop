# Field Android demo setup

The field app is an offline-first Flutter Android client. For a physical demo:

1. Install Flutter 3.35 or newer and Android Studio with an Android SDK/API level
   supported by the checked-in Gradle configuration.
2. Connect a low-end Android phone with developer options and USB debugging
   enabled, then accept the debugging prompt.
3. From the repository root run `flutter pub get` and
   `flutter devices`; select the phone with `flutter run -d <device-id>`.
4. Grant camera access when prompted. Use **Scan water point QR** or enter the
   printed opaque point code manually.
5. To demonstrate offline behavior, use Profile > pause sync (or airplane mode),
   complete a check, capture photo evidence, and queue it. Reconnect and use
   **Sync now**; the pending record and photo upload retry until the server
   acknowledges them.

Photo evidence is written to the local app database/outbox first. Supabase
uploads it to the private `inspection-evidence` bucket only during a connected
sync; unknown or revoked QR identifiers never open a field assignment.
