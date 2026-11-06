import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:uuid/uuid.dart';
import 'outbox.dart';
import 'photos.dart';
import 'storage.dart';

class WorkDraft {
  const WorkDraft(
    this.command, {
    this.state = DraftState.draft,
    this.attempts = 0,
    this.retryAt,
    this.error,
    this.receipt,
  });
  final WorkStepCommand command;
  final DraftState state;
  final int attempts;
  final DateTime? retryAt;
  final String? error;
  final WorkStepReceipt? receipt;
  Map<String, Object?> toJson() => {
    'command': command.toJson(),
    'state': state.name,
    'attempts': attempts,
    'retry_at': retryAt?.toUtc().toIso8601String(),
    'error': error,
    'receipt': receipt?.toJson(),
  };
  factory WorkDraft.fromJson(Map<String, dynamic> j) => WorkDraft(
    WorkStepCommand.fromJson(j['command'] as Map<String, dynamic>),
    state: DraftState.values.byName(j['state'] as String),
    attempts: j['attempts'] as int,
    retryAt: j['retry_at'] == null
        ? null
        : DateTime.parse(j['retry_at'] as String),
    error: j['error'] as String?,
    receipt: j['receipt'] == null
        ? null
        : WorkStepReceipt.fromJson(j['receipt'] as Map<String, dynamic>),
  );
}

/// Each acknowledged version permits one further local step. Offline workers
/// can prepare the next step only after the server confirms the preceding one.
class WorkOrderOutbox extends ChangeNotifier {
  WorkOrderOutbox({
    required this.store,
    required this.namespace,
    required this.scope,
  });
  final KeyValueStore store;
  final String namespace;
  final Scope scope;
  List<WorkDraft> _entries = [];
  Future<void> _tail = Future.value();
  bool syncing = false;
  int _generation = 0;
  List<WorkDraft> get entries => List.unmodifiable(_entries);
  LocalPhotos get photos => LocalPhotos(store, namespace);
  String get storageKey =>
      'work-outbox:$namespace:${scope.organizationId}:${scope.facilityId}';
  int get pendingCount =>
      _entries.where((e) => e.state == DraftState.pending).length;
  int get failedCount => _entries.where((e) => e.error != null).length;
  WorkDraft? forOrder(FieldWorkOrder order) => _entries
      .where(
        (e) =>
            e.command.orderId == order.id &&
            e.command.expectedVersion == order.version,
      )
      .firstOrNull;
  Future<void> load() async {
    final value = await store.read(storageKey);
    if (value == null) return;
    final document = jsonDecode(value) as Map<String, dynamic>;
    if (document['version'] != 1) {
      throw const FormatException('Update the app to read saved work.');
    }
    final entries = (document['entries'] as List)
        .map((j) => WorkDraft.fromJson(j as Map<String, dynamic>))
        .toList();
    requireRule(
      entries.every((e) => e.command.scope.matches(scope)),
      'cache_scope',
      'Wrong facility cache.',
    );
    _entries = entries;
    notifyListeners();
  }

  Future<void> _serial(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _replace(WorkDraft draft) async {
    final next = [..._entries];
    final index = next.indexWhere(
      (e) => e.command.stepKey == draft.command.stepKey,
    );
    if (index < 0) {
      next.add(draft);
    } else {
      next[index] = draft;
    }
    await store.write(
      storageKey,
      jsonEncode({
        'version': 1,
        'entries': next.map((e) => e.toJson()).toList(),
      }),
    );
    _entries = next;
    notifyListeners();
  }

  Future<void> save({
    required FieldWorkOrder order,
    required String actorId,
    required String notes,
    required DateTime observedAt,
    List<InspectionEvidence> evidence = const [],
  }) => _serial(() async {
    requireRule(
      order.scope.matches(scope) && order.assigneeId == actorId,
      'assignee_required',
      'Only your assigned work can be saved.',
    );
    requireRule(
      {
        WorkOrderState.assigned,
        WorkOrderState.rework,
        WorkOrderState.inProgress,
      }.contains(order.state),
      'step_unavailable',
      'This work order is waiting for manager review.',
    );
    final previous = forOrder(order);
    requireRule(
      previous == null || previous.state == DraftState.draft,
      'draft_locked',
      'Queued work is immutable.',
    );
    await _replace(
      WorkDraft(
        WorkStepCommand(
          clientEventId: previous?.command.clientEventId ?? const Uuid().v4(),
          orderId: order.id,
          scope: scope,
          expectedVersion: order.version,
          target: order.state == WorkOrderState.inProgress
              ? WorkOrderState.completed
              : WorkOrderState.inProgress,
          notes: notes,
          observedAt: observedAt,
          isSimulated: order.isSimulated,
          evidence: evidence,
        ),
      ),
    );
  });
  Future<void> enqueue(FieldWorkOrder order) => _serial(() async {
    final draft = forOrder(order);
    requireRule(draft != null, 'draft_missing', 'Save the step first.');
    if (draft!.state != DraftState.draft) return;
    requireRule(
      draft.command.notes.trim().isNotEmpty ||
          draft.command.evidence.isNotEmpty,
      'evidence_required',
      'Describe the action or attach a photo.',
    );
    await _replace(WorkDraft(draft.command, state: DraftState.pending));
  });
  Future<void> sync(
    TankLoopRepository repository, {
    required bool online,
    bool retryNow = false,
  }) async {
    if (!online || syncing || repository is! FieldWorkRepository) return;
    final workRepository = repository as FieldWorkRepository;
    final generation = _generation;
    syncing = true;
    notifyListeners();
    try {
      await _tail;
      for (final draft
          in _entries
              .where(
                (e) =>
                    e.state == DraftState.pending &&
                    (retryNow ||
                        e.retryAt == null ||
                        !e.retryAt!.isAfter(DateTime.now())),
              )
              .toList()) {
        var command = draft.command;
        final attempt = draft.attempts + 1;
        await _serial(
          () => _replace(
            WorkDraft(command, state: DraftState.pending, attempts: attempt),
          ),
        );
        try {
          if (repository case final EvidenceUploader uploader) {
            for (final photo in command.evidence) {
              if (photo.uploadedPath != null) continue;
              final path = await uploader
                  .uploadEvidence(photo, bytes: await photos.read(photo))
                  .timeout(const Duration(seconds: 30));
              if (generation != _generation) return;
              command = command.withEvidence(
                command.evidence
                    .map(
                      (p) =>
                          p.id == photo.id ? p.copyWith(uploadedPath: path) : p,
                    )
                    .toList(),
              );
              await _serial(
                () => _replace(
                  WorkDraft(
                    command,
                    state: DraftState.pending,
                    attempts: attempt,
                  ),
                ),
              );
            }
          }
          final receipt = await workRepository
              .submitWorkStep(command)
              .timeout(const Duration(seconds: 30));
          if (generation != _generation) return;
          requireRule(
            receipt.clientEventId == command.clientEventId &&
                receipt.orderId == command.orderId &&
                receipt.version == command.expectedVersion + 1,
            'invalid_receipt',
            'Receipt does not match this work step.',
          );
          await _serial(
            () => _replace(
              WorkDraft(
                command,
                state: DraftState.synced,
                attempts: attempt,
                receipt: receipt,
              ),
            ),
          );
        } catch (error) {
          if (generation != _generation) return;
          final permanent =
              error is RuleViolation ||
              error is FormatException ||
              error is RepositoryFailure && error.kind != FailureKind.transient;
          await _serial(
            () => _replace(
              WorkDraft(
                command,
                state: permanent ? DraftState.blocked : DraftState.pending,
                attempts: attempt,
                retryAt: permanent
                    ? null
                    : DateTime.now().add(
                        Duration(seconds: min(300, 1 << min(attempt, 8))),
                      ),
                error: error is RepositoryFailure
                    ? error.message
                    : 'Sync failed. Saved work is retained; retry or ask your manager to review.',
              ),
            ),
          );
        }
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> clear() {
    _generation++;
    return _serial(() async {
      for (final entry in _entries) {
        for (final photo in entry.command.evidence) {
          await photos.remove(photo.id);
        }
      }
      await store.remove(storageKey);
      _entries = [];
      notifyListeners();
    });
  }
}
