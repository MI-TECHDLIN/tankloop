import 'package:tankloop_offline_sync/offline_sync.dart';

String draftLabel(DraftState state) => switch (state) {
  DraftState.draft => 'Draft saved on device',
  DraftState.pending => 'Pending sync',
  DraftState.synced => 'Receipt received',
  DraftState.blocked => 'Sync failed - needs review',
};
String entryLabel(OutboxEntry entry) =>
    entry.error != null && entry.state == DraftState.pending
    ? 'Sync failed - retry available'
    : draftLabel(entry.state);
