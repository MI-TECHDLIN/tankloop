import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tankloop_data/data.dart';
import 'package:uuid/uuid.dart';

enum LabPhase {
  loading,
  empty,
  error,
  permissionDenied,
  offline,
  stale,
  success,
}

/// Screen state is a projection of repository responses. There is deliberately
/// no optimistic result transition and no offline attestation outbox.
class LabController extends ChangeNotifier {
  LabController(this.repository, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  static const freshnessWindow = Duration(minutes: 5);
  final LabRepository repository;
  final DateTime Function() clock;
  LabPhase phase = LabPhase.loading;
  LabWorkspace? workspace;
  LabReceipt? receipt;
  String? message;
  String? commandError;
  String? _facilityId;
  bool busy = false;
  bool refreshing = false;
  bool _offlineExercise = false;
  bool get offlineExercise => _offlineExercise;
  bool _disposed = false;
  int _generation = 0;
  int _sessionGeneration = 0;
  Timer? _staleTimer;
  LabCommand? _pendingCommand;
  bool get _connected =>
      repository.serverBacked &&
      phase == LabPhase.success &&
      !busy &&
      !refreshing &&
      workspace != null;
  bool get canWrite => _connected && _pendingCommand == null;
  bool get canRetry => _connected && _pendingCommand != null;
  bool get hasPendingCommand => _pendingCommand != null;

  Future<void> refresh({String? facilityId}) async {
    if (_disposed) return;
    if (facilityId != null && facilityId != _facilityId) {
      _clearPrivateData();
      _facilityId = facilityId;
    }
    final token = ++_generation;
    _staleTimer?.cancel();
    if (_offlineExercise) {
      refreshing = false;
      phase = LabPhase.offline;
      notifyListeners();
      return;
    }
    refreshing = true;
    // Cached forms remain mounted during a refresh so in-tab drafts survive.
    // Write actions stay disabled until the authoritative snapshot arrives.
    if (workspace == null) phase = LabPhase.loading;
    message = null;
    notifyListeners();
    try {
      final data = await repository.load(facilityId: _facilityId);
      if (_disposed || token != _generation) return;
      workspace = data;
      _facilityId = data.facility.id;
      final remaining =
          freshnessWindow - clock().toUtc().difference(data.fetchedAt);
      phase = remaining <= Duration.zero
          ? LabPhase.stale
          : data.records.isEmpty
          ? LabPhase.empty
          : LabPhase.success;
      if (remaining > Duration.zero) {
        _staleTimer = Timer(remaining, () {
          if (_disposed || token != _generation) return;
          phase = LabPhase.stale;
          notifyListeners();
        });
      }
    } catch (error) {
      if (_disposed || token != _generation) return;
      if (error is RepositoryFailure && error.kind == FailureKind.permission) {
        _denyAccess(error.message);
        return;
      } else if (error is LabConnectionFailure) {
        phase = LabPhase.offline;
      } else {
        phase = LabPhase.error;
      }
      message = error is RepositoryFailure
          ? error.message
          : 'The laboratory record could not be loaded. Please retry.';
    } finally {
      if (!_disposed && token == _generation) {
        refreshing = false;
        notifyListeners();
      }
    }
  }

  Future<LabReceipt?> submit({
    required LabRecord record,
    required int expectedVersion,
    required LabAction action,
    required Map<String, Object?> payload,
    required String reason,
  }) async {
    if (!canWrite) return null;
    _pendingCommand = LabCommand(
      eventId: const Uuid().v4(),
      resultId: record.id,
      expectedVersion: expectedVersion,
      action: action,
      payload: payload,
      reason: reason,
    );
    return _send(_pendingCommand!);
  }

  /// Resolve a lost acknowledgement even if the refreshed record has already
  /// advanced to a different stage. The server returns the original receipt.
  Future<LabReceipt?> retryPending() async =>
      canRetry ? _send(_pendingCommand!) : null;

  Future<LabReceipt?> _send(LabCommand command) async {
    final token = _sessionGeneration;
    busy = true;
    commandError = null;
    receipt = null;
    notifyListeners();
    try {
      final received = await repository.submit(command);
      if (_disposed || token != _sessionGeneration) return null;
      receipt = received;
      _pendingCommand = null;
      // Keep the old view read-only until an authoritative refresh completes.
      await refresh();
      return _disposed || token != _sessionGeneration ? null : received;
    } catch (error) {
      if (_disposed || token != _sessionGeneration) return null;
      if (error is RepositoryFailure && error.kind == FailureKind.permission) {
        _denyAccess(error.message);
        return null;
      } else if (error is LabConnectionFailure) {
        _staleTimer?.cancel();
        phase = LabPhase.offline;
      } else if (error is RepositoryFailure &&
          error.kind == FailureKind.conflict) {
        _staleTimer?.cancel();
        _pendingCommand = null;
        phase = LabPhase.stale;
      } else if (error is RepositoryFailure &&
          error.kind == FailureKind.invalid) {
        _pendingCommand = null;
      }
      commandError = error is RepositoryFailure
          ? error.message
          : 'The lab action could not be confirmed. Retry the same request after reconnecting.';
      return null;
    } finally {
      if (!_disposed && token == _sessionGeneration) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void sessionChanged() {
    if (_disposed) return;
    ++_generation;
    _clearPrivateData();
    phase = LabPhase.permissionDenied;
    notifyListeners();
  }

  Future<void> setOfflineExercise(bool offline) async {
    _offlineExercise = offline;
    await refresh();
  }

  void _denyAccess(String reason) {
    ++_generation;
    _clearPrivateData();
    phase = LabPhase.permissionDenied;
    message = reason;
    notifyListeners();
  }

  void _clearPrivateData() {
    ++_sessionGeneration;
    _staleTimer?.cancel();
    workspace = null;
    receipt = null;
    _facilityId = null;
    _pendingCommand = null;
    commandError = null;
    message = null;
    busy = false;
    refreshing = false;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    ++_sessionGeneration;
    _staleTimer?.cancel();
    super.dispose();
  }
}
