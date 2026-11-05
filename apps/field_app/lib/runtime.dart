import 'dart:convert';
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
    final simulation = config.mode == AppMode.simulation;
    final repo =
        repository ??
        (simulation
            ? SimulationRepository(seed: config.seed, day: config.day)
            : SupabaseTankLoopRepository(Supabase.instance.client));
    final identity = simulation
        ? 'simulation:${config.seed}:${config.day}'
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
      dashboard = DashboardSnapshot.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
      stale = true;
    }
    final outbox = InspectionOutbox(
      store: store,
      namespace: '$identity:${dashboard.actorId}',
      scope: dashboard.scope,
    );
    await outbox.load();
    final workOutbox = WorkOrderOutbox(
      store: store,
      namespace: '$identity:${dashboard.actorId}',
      scope: dashboard.scope,
    );
    await workOutbox.load();
    if (repo is SimulationRepository) {
      final delivered = outbox.entries.where((e) => e.receipt != null).toList()
        ..sort(
          (a, b) => a.receipt!.receivedAt.compareTo(b.receipt!.receivedAt),
        );
      for (final entry in delivered) {
        if (entry.receipt!.receivedAt.isAfter(repo.engine.now)) {
          repo.engine.advanceTo(entry.receipt!.receivedAt);
        }
        await repo.submitInspection(entry.command);
      }
      for (final draft
          in workOutbox.entries.where((e) => e.receipt != null).toList()..sort(
            (a, b) => a.receipt!.receivedAt.compareTo(b.receipt!.receivedAt),
          )) {
        if (draft.receipt!.receivedAt.isAfter(repo.engine.now)) {
          repo.engine.advanceTo(draft.receipt!.receivedAt);
        }
        await repo.submitWorkStep(draft.command);
      }
      final clock = await store.read('clock:$identity');
      if (clock != null && DateTime.parse(clock).isAfter(repo.engine.now)) {
        repo.engine.advanceTo(DateTime.parse(clock));
      }
      dashboard = await repo.today();
    }
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

  Future<void> advanceDay() async {
    final repo = repository;
    if (repo is! SimulationRepository) return;
    repo.engine.advance(const Duration(days: 1));
    await store.write('clock:$identity', repo.engine.now.toIso8601String());
    await refresh();
  }

  String publicUrl(String token) {
    final repo = repository;
    final query = repo is SimulationRepository
        ? '?seed=${repo.engine.seed}&day=${repo.engine.now.difference(repo.engine.startsAt).inDays}'
        : '';
    return '${config.portalBaseUrl.replaceFirst(RegExp(r'/$'), '')}/#/point/$token$query';
  }

  Future<void> resume() async {
    try {
      await photoCapture.recover();
    } catch (_) {
      error =
          'A camera capture needs recovery. Keep this account signed in and retry.';
      notifyListeners();
    }
    if (config.mode == AppMode.supabase && !syncPaused) await sync();
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
    await store.remove(cacheKey);
    await store.remove('clock:$identity');
    await store.remove(photoCapture.key);
  }
}
