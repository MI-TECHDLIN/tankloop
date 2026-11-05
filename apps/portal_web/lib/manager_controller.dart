import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tankloop_data/data.dart';

enum ManagerViewState { loading, empty, error, denied, offline, stale, success }

class ManagerController extends ChangeNotifier {
  ManagerController(this.repository, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  static const freshnessWindow = Duration(minutes: 5);
  final ManagerWorkspaceRepository repository;
  final DateTime Function() clock;
  ManagerWorkspace? workspace;
  ManagerViewState phase = ManagerViewState.loading;
  String? message;
  String? actionMessage;
  bool busy = false;
  bool refreshing = false;
  bool offlineExercise = false;
  bool _disposed = false;
  int _generation = 0;
  int _session = 0;
  String? _facilityId;
  Timer? _freshnessTimer;

  bool get canWrite =>
      phase == ManagerViewState.success &&
      !busy &&
      !refreshing &&
      !offlineExercise &&
      workspace != null &&
      clock().toUtc().difference(workspace!.fetchedAt) < freshnessWindow;

  Future<void> refresh({String? facilityId}) async {
    if (_disposed) return;
    if (facilityId != null && facilityId != _facilityId) {
      _clear();
      _facilityId = facilityId;
    }
    final generation = ++_generation;
    _freshnessTimer?.cancel();
    if (offlineExercise) {
      refreshing = false;
      phase = ManagerViewState.offline;
      notifyListeners();
      return;
    }
    refreshing = true;
    message = null;
    if (workspace == null) phase = ManagerViewState.loading;
    notifyListeners();
    try {
      final data = await repository.load(facilityId: _facilityId);
      if (_disposed || generation != _generation) return;
      workspace = data;
      _facilityId = data.facility.id;
      final remaining =
          freshnessWindow - clock().toUtc().difference(data.fetchedAt);
      phase = remaining <= Duration.zero
          ? ManagerViewState.stale
          : ManagerViewState.success;
      if (remaining > Duration.zero) {
        _freshnessTimer = Timer(remaining, () {
          if (_disposed || generation != _generation) return;
          phase = ManagerViewState.stale;
          notifyListeners();
        });
      }
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _failure(error);
    } finally {
      if (!_disposed && generation == _generation) {
        refreshing = false;
        notifyListeners();
      }
    }
  }

  /// The existing commands are version-guarded. Never apply an optimistic state
  /// change or queue a privileged action while offline.
  Future<bool> act(
    Future<Object?> Function() command,
    String confirmation, {
    required ManagerWorkspace basedOn,
  }) async {
    if (!canWrite) return false;
    if (!identical(workspace, basedOn)) {
      actionMessage =
          'The records changed while this action was open. Review the current record and try again.';
      notifyListeners();
      return false;
    }
    final session = _session;
    busy = true;
    actionMessage = null;
    notifyListeners();
    try {
      await command();
      if (_disposed || session != _session) return false;
      actionMessage =
          '${repository.serverBacked ? 'Server acknowledged' : 'Simulated action recorded'}: $confirmation';
      await refresh();
      return !_disposed && session == _session;
    } catch (error) {
      if (_disposed || session != _session) return false;
      _failure(error, action: true);
      return false;
    } finally {
      if (!_disposed && session == _session) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void _failure(Object error, {bool action = false}) {
    final text = error is RepositoryFailure
        ? error.message
        : 'The manager request could not be confirmed. Refresh before trying again.';
    if (action &&
        error is RepositoryFailure &&
        error.kind == FailureKind.invalid) {
      actionMessage = text;
      return;
    }
    _freshnessTimer?.cancel();
    if (error is RepositoryFailure && error.kind == FailureKind.permission) {
      _clear();
      phase = ManagerViewState.denied;
      message = text;
    } else {
      if (action) {
        actionMessage = text;
      } else {
        message = text;
      }
      if (error is ManagerConnectionFailure) {
        phase = ManagerViewState.offline;
      } else if (error is RepositoryFailure &&
          error.kind == FailureKind.conflict) {
        phase = ManagerViewState.stale;
      } else {
        phase = ManagerViewState.error;
      }
    }
  }

  Future<void> setOfflineExercise(bool value) async {
    if (repository.serverBacked || busy) return;
    offlineExercise = value;
    await refresh();
  }

  void sessionChanged() {
    if (_disposed) return;
    ++_generation;
    _clear();
    phase = ManagerViewState.denied;
    notifyListeners();
  }

  void _clear() {
    ++_session;
    _freshnessTimer?.cancel();
    workspace = null;
    _facilityId = null;
    message = null;
    actionMessage = null;
    busy = false;
    refreshing = false;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _clear();
    super.dispose();
  }
}
