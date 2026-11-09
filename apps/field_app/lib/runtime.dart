import 'dart:convert';
import 'handover/handover.dart';
import 'photo_capture.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

final runtimeProvider = Provider<FieldRuntime>(
  (ref) => throw StateError('Field runtime has not been initialized.'),
);

class FieldRuntime extends ChangeNotifier {
  FieldRuntime._({
    required this.config,
    required this.store,
    required this.repository,
    required this.dashboard,
    required this.outbox,
    required this.workOutbox,
    required this.identity,
    required this.stale,
  });
  final AppConfig config;
  final KeyValueStore store;
  final TankLoopRepository repository;
  DashboardSnapshot dashboard;
  final InspectionOutbox outbox;
  final WorkOrderOutbox workOutbox;
  final String identity;
  bool stale;
  bool online = true;
  bool syncPaused = false;
  late final photoCapture = FieldPhotoCapture(this);
  bool refreshing = false;
  String? error;
  bool accessRevoked = false;
  bool _cleared = false;
  int get pendingCount => outbox.pendingCount + workOutbox.pendingCount;
  int get failedCount => outbox.failedCount + workOutbox.failedCount;
  String get cacheKey => 'dashboard:$identity';

  static Future<FieldRuntime> create(
    AppConfig config,
    KeyValueStore store, {
    TankLoopRepository? repository,
    String? userId,
  }) async {
    final repo =
        repository ??
        SupabaseTankLoopRepository(
          Supabase.instance.client,
          includeSimulated: false,
        );
    final identity = repository != null
        ? '${config.supabaseUrl}:${userId ?? 'test-user'}'
        : '${config.supabaseUrl}:${userId ?? Supabase.instance.client.auth.currentUser!.id}';
    DashboardSnapshot dashboard;
    var stale = false;
    try {
      final cached = await store.read('dashboard:$identity');
      dashboard = await repo.today().timeout(
        Duration(seconds: cached == null ? 20 : 3),
      );
      await store.write('dashboard:$identity', jsonEncode(dashboard.toJson()));
    } catch (error) {
      if (error is RepositoryFailure && error.kind == FailureKind.permission) {
        await store.remove('dashboard:$identity');
        rethrow;
      }
      final cached = await store.read('dashboard:$identity');
      if (cached == null) rethrow;
      final document = jsonDecode(cached) as Map<String, dynamic>;
      if (_containsGeneratedRecords(document)) {
        throw const RepositoryFailure(
          FailureKind.transient,
          'Connect to load current assignments. Previous exercise records are not available in Field; saved drafts are retained on this device.',
        );
      }
      dashboard = DashboardSnapshot.fromJson(document);
      stale = true;
    }
    final outbox = InspectionOutbox(
      store: store,
      namespace: '$identity:${dashboard.actorId}',
      scope: dashboard.scope,
    );
    await _quarantineGeneratedEntries(store, outbox.storageKey);
    await outbox.load();
    final workOutbox = WorkOrderOutbox(
      store: store,
      namespace: '$identity:${dashboard.actorId}',
      scope: dashboard.scope,
    );
    await _quarantineGeneratedEntries(store, workOutbox.storageKey);
    await workOutbox.load();
    return FieldRuntime._(
      config: config,
      store: store,
      repository: repo,
      dashboard: dashboard,
      outbox: outbox,
      workOutbox: workOutbox,
      identity: identity,
      stale: stale,
    );
  }

  static bool _containsGeneratedRecords(Object? value) => switch (value) {
    Map() =>
      value['is_simulated'] == true ||
          value.values.any(_containsGeneratedRecords),
    List() => value.any(_containsGeneratedRecords),
    _ => false,
  };

  // Preserve old exercise drafts without rendering or uploading them as field work.
  static Future<void> _quarantineGeneratedEntries(
    KeyValueStore store,
    String key,
  ) async {
    final saved = await store.read(key);
    if (saved == null) return;
    final document = jsonDecode(saved) as Map<String, dynamic>;
    if (document['version'] != 1) return;
    final entries = document['entries'] as List;
    if (!entries.any(_containsGeneratedRecords)) return;
    final archiveKey = 'quarantined:$key';
    final archived = await store.read(archiveKey);
    final previous = archived == null
        ? <dynamic>[]
        : (jsonDecode(archived) as Map<String, dynamic>)['entries'] as List;
    await store.write(
      archiveKey,
      jsonEncode({
        ...document,
        'entries': [...previous, ...entries.where(_containsGeneratedRecords)],
      }),
    );
    await store.write(
      key,
      jsonEncode({
        ...document,
        'entries': entries
            .where((entry) => !_containsGeneratedRecords(entry))
            .toList(),
      }),
    );
  }

  Future<void> refresh() async {
    if (refreshing || _cleared) return;
    refreshing = true;
    error = null;
    notifyListeners();
    try {
      final updated = await repository.today().timeout(
        const Duration(seconds: 20),
      );
      if (_cleared) return;
      online = !syncPaused;
      await store.write(cacheKey, jsonEncode(updated.toJson()));
      dashboard = updated;
      accessRevoked = false;
      stale = false;
    } catch (failure) {
      stale = true;
      if (failure is! RepositoryFailure ||
          failure.kind == FailureKind.transient) {
        online = false;
      }
      if (failure is RepositoryFailure &&
          failure.kind == FailureKind.permission) {
        accessRevoked = true;
        await store.remove(cacheKey);
      }
      error = failure is RepositoryFailure
          ? failure.message
          : 'Could not refresh. Previously loaded assignments and local drafts are retained.';
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> sync() async {
    if (accessRevoked || syncPaused) return;
    if (!online) await refresh();
    await outbox.sync(repository, online: online, retryNow: true);
    await workOutbox.sync(repository, online: online, retryNow: true);
    if (online) await refresh();
  }

  void toggleConnection() {
    syncPaused = !syncPaused;
    online = !syncPaused;
    notifyListeners();
  }

  String publicUrl(String token) {
    return '${config.portalBaseUrl.replaceFirst(RegExp(r'/$'), '')}/#/point/$token';
  }

  Future<void> resume() async {
    try {
      await photoCapture.recover();
    } catch (_) {
      error =
          'A camera capture needs recovery. Keep this account signed in and retry.';
      notifyListeners();
    }
    if (!syncPaused) await sync();
  }

  @override
  void dispose() {
    workOutbox.dispose();
    super.dispose();
  }

  Future<void> clearDeviceData() async {
    _cleared = true;
    accessRevoked = true;
    await outbox.clear();
    await workOutbox.clear();
    await store.remove('quarantined:${outbox.storageKey}');
    await store.remove('quarantined:${workOutbox.storageKey}');
    await store.remove(cacheKey);
    await store.remove(photoCapture.key);
    await store.remove(
      handoverStorageKey(identity, dashboard.scope.facilityId),
    );
  }
}
