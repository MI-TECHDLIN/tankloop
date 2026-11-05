import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';

enum PublicPointPhase {
  loading,
  empty,
  error,
  permissionDenied,
  offline,
  stale,
  success,
}

class PublicPointController extends ChangeNotifier {
  PublicPointController({
    required this.repository,
    required this.token,
    required bool Function() isOnline,
    Stream<bool> connectivity = const Stream.empty(),
    DateTime Function()? clock,
  }) : _isOnline = isOnline,
       _clock = clock ?? DateTime.now {
    _connection = connectivity.listen((online) {
      if (online) {
        unawaited(refresh());
      } else {
        _request++;
        refreshing = false;
        isSnapshot = record != null;
        phase = PublicPointPhase.offline;
        notifyListeners();
      }
    });
    _expiry = Timer.periodic(const Duration(minutes: 1), (_) => checkAge());
  }
  final PublicPointRepository repository;
  final String token;
  final bool Function() _isOnline;
  final DateTime Function() _clock;
  late final StreamSubscription<bool> _connection;
  late final Timer _expiry;
  PublicPointPhase phase = PublicPointPhase.loading;
  PublicPointLookup? lookup;
  PublicWaterRecord? get record => lookup?.record;
  DateTime? loadedAt;
  bool refreshing = false;
  bool isSnapshot = false;
  bool _disposed = false;
  int _request = 0;

  bool get online => _isOnline();
  bool get canReport =>
      online &&
      record != null &&
      !refreshing &&
      !isSnapshot &&
      {PublicPointPhase.success, PublicPointPhase.stale}.contains(phase);

  Future<void> refresh() async {
    if (_disposed || refreshing) return;
    if (!online) {
      phase = PublicPointPhase.offline;
      isSnapshot = record != null;
      notifyListeners();
      return;
    }
    final request = ++_request;
    refreshing = true;
    if (record == null) phase = PublicPointPhase.loading;
    notifyListeners();
    try {
      final result = await repository
          .lookup(token)
          .timeout(const Duration(seconds: 20));
      if (_disposed || request != _request) return;
      lookup = result;
      loadedAt = _clock().toUtc();
      isSnapshot = false;
      phase = result.record == null
          ? PublicPointPhase.empty
          : !result.record!.isCurrent && result.record!.tests.isNotEmpty
          ? PublicPointPhase.stale
          : PublicPointPhase.success;
    } catch (error) {
      if (_disposed || request != _request) return;
      if (error is PublicRequestFailure &&
          error.kind == PublicFailureKind.permission) {
        lookup = null;
        loadedAt = null;
        phase = PublicPointPhase.permissionDenied;
      } else if (error is PublicRequestFailure &&
          error.kind == PublicFailureKind.revoked) {
        lookup = const PublicPointLookup.revoked();
        loadedAt = null;
        phase = PublicPointPhase.empty;
      } else {
        isSnapshot = record != null;
        phase = !online
            ? PublicPointPhase.offline
            : isSnapshot
            ? PublicPointPhase.stale
            : PublicPointPhase.error;
      }
    } finally {
      if (!_disposed && request == _request) {
        refreshing = false;
        notifyListeners();
      }
    }
  }

  void checkAge() {
    if (record != null &&
        loadedAt != null &&
        !isSnapshot &&
        !refreshing &&
        _clock().toUtc().difference(loadedAt!) >= const Duration(minutes: 5)) {
      isSnapshot = true;
      phase = online ? PublicPointPhase.stale : PublicPointPhase.offline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    _expiry.cancel();
    unawaited(_connection.cancel());
    super.dispose();
  }
}
