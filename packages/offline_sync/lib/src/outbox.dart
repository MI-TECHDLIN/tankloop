import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:uuid/uuid.dart';
import 'storage.dart';

enum DraftState { draft, pending, synced, blocked }

class OutboxEntry {
  const OutboxEntry({
    required this.command,
    this.state = DraftState.draft,
    this.attempts = 0,
    this.nextAttemptAt,
    this.error,
    this.receipt,
  });
  final InspectionSubmission command;
  final DraftState state;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? error;
  final SyncReceipt? receipt;
  Map<String, Object?> toJson() => {
    'command': command.toJson(),
    'state': state.name,
    'attempts': attempts,
    'next_attempt_at': nextAttemptAt?.toUtc().toIso8601String(),
    'error': error,
    'receipt': receipt?.toJson(),
  };
  factory OutboxEntry.fromJson(Map<String, dynamic> j) => OutboxEntry(
    command: InspectionSubmission.fromJson(
      j['command'] as Map<String, dynamic>,
    ),
    state: DraftState.values.byName(j['state'] as String),
    attempts: j['attempts'] as int,
    nextAttemptAt: j['next_attempt_at'] == null
        ? null
        : DateTime.parse(j['next_attempt_at'] as String),
    error: j['error'] as String?,
    receipt: j['receipt'] == null
        ? null
        : SyncReceipt.fromJson(j['receipt'] as Map<String, dynamic>),
  );
}

class InspectionOutbox extends ChangeNotifier {
  InspectionOutbox({
    required this.store,
    required this.namespace,
    required this.scope,
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random();
  final KeyValueStore store;
  final String namespace;
  final Scope scope;
  final DateTime Function() _clock;
  final Random _random;
  List<OutboxEntry> _entries = [];
  Future<void> _tail = Future.value();
  bool syncing = false;
  List<OutboxEntry> get entries => List.unmodifiable(_entries);
  int get pendingCount =>
      _entries.where((e) => e.state == DraftState.pending).length;
  int get blockedCount =>
      _entries.where((e) => e.state == DraftState.blocked).length;
  String get storageKey =>
      'outbox:$namespace:${scope.organizationId}:${scope.facilityId}';
  OutboxEntry? forTask(String taskId) =>
      _entries.where((e) => e.command.taskId == taskId).firstOrNull;

  Future<void> load() async {
    final value = await store.read(storageKey);
    if (value == null) return;
    final document = jsonDecode(value) as Map<String, dynamic>;
    if (document['version'] != 1) {
      throw const FormatException(
        'The saved draft format needs an app update.',
      );
    }
    final restored = (document['entries'] as List)
        .map((e) => OutboxEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    requireRule(
      restored.every((e) => e.command.scope.matches(scope)),
      'cache_scope',
      'A saved record belongs to a different facility.',
    );
    _entries = restored;
    notifyListeners();
  }

  Future<void> _serial(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _replace(OutboxEntry entry) async {
    final next = [..._entries];
    final index = next.indexWhere(
      (e) => e.command.taskId == entry.command.taskId,
    );
    if (index < 0) {
      next.add(entry);
    } else {
      next[index] = entry;
    }
    // Persist first. The UI must never say Saved for an unsuccessful write.
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
    required InspectionTask task,
    required Map<String, InspectionAnswer> answers,
    required String notes,
    required DateTime observedAt,
    List<InspectionEvidence> evidence = const [],
  }) => _serial(() async {
    requireRule(
      task.scope.matches(scope),
      'cache_scope',
      'This assignment is outside the active facility.',
    );
    final prior = forTask(task.id);
    requireRule(
      prior == null || prior.state == DraftState.draft,
      'draft_locked',
      'Submitted content is immutable. Review a conflict explicitly.',
    );
    final command = InspectionSubmission(
      clientEventId: prior?.command.clientEventId ?? const Uuid().v4(),
      taskId: task.id,
      scope: scope,
      templateId: task.templateId,
      expectedVersion: prior?.command.expectedVersion ?? task.version,
      observedAt: observedAt,
      answers: answers,
      notes: notes,
      evidence: evidence,
      isSimulated: task.isSimulated,
    );
    await _replace(OutboxEntry(command: command));
  });

  Future<void> enqueue(String taskId, ChecklistTemplate template) =>
      _serial(() async {
        final entry = forTask(taskId);
        requireRule(
          entry != null,
          'draft_missing',
          'Save the inspection on this device first.',
        );
        if (entry!.state != DraftState.draft) return;
        entry.command.validate(template);
        // Draft and queued command are in the same atomic snapshot.
        await _replace(
          OutboxEntry(command: entry.command, state: DraftState.pending),
        );
      });

  Future<void> markEvidenceUploaded(
    String taskId,
    String evidenceId,
    String uploadedPath,
  ) => _serial(() async {
    final entry = forTask(taskId);
    if (entry == null) return;
    final evidence = entry.command.evidence
        .map(
          (item) => item.id == evidenceId
              ? item.copyWith(uploadedPath: uploadedPath)
              : item,
        )
        .toList();
    final command = InspectionSubmission(
      clientEventId: entry.command.clientEventId,
      taskId: entry.command.taskId,
      scope: entry.command.scope,
      templateId: entry.command.templateId,
      expectedVersion: entry.command.expectedVersion,
      observedAt: entry.command.observedAt,
      answers: entry.command.answers,
      notes: entry.command.notes,
      evidence: evidence,
      isSimulated: entry.command.isSimulated,
    );
    await _replace(
      OutboxEntry(
        command: command,
        state: entry.state,
        attempts: entry.attempts,
        nextAttemptAt: entry.nextAttemptAt,
        error: entry.error,
        receipt: entry.receipt,
      ),
    );
  });

  Future<void> sync(
    TankLoopRepository repository, {
    required bool online,
    bool retryNow = false,
  }) async {
    if (!online || syncing) return;
    syncing = true;
    notifyListeners();
    try {
      await _tail;
      final ready = _entries
          .where(
            (e) =>
                e.state == DraftState.pending &&
                (retryNow ||
                    e.nextAttemptAt == null ||
                    !e.nextAttemptAt!.isAfter(_clock())),
          )
          .toList();
      for (final entry in ready) {
        final attempt = entry.attempts + 1;
        await _serial(
          () => _replace(
            OutboxEntry(
              command: entry.command,
              state: DraftState.pending,
              attempts: attempt,
            ),
          ),
        );
        try {
          var command = entry.command;
          if (repository case final EvidenceUploader uploader) {
            for (final item in command.evidence) {
              if (item.uploadedPath == null) {
                final uploaded = await uploader.uploadEvidence(item);
                await markEvidenceUploaded(command.taskId, item.id, uploaded);
                command = forTask(command.taskId)!.command;
              }
            }
          }
          final receipt = await repository.submitInspection(command);
          requireRule(
            receipt.clientEventId == entry.command.clientEventId &&
                receipt.inspectionId == entry.command.taskId &&
                receipt.version == entry.command.expectedVersion + 1,
            'invalid_receipt',
            'The server receipt does not match this queued command.',
          );
          await _serial(
            () => _replace(
              OutboxEntry(
                command: entry.command,
                state: DraftState.synced,
                attempts: attempt,
                receipt: receipt,
              ),
            ),
          );
        } catch (error) {
          final permanent =
              error is RuleViolation ||
              error is RepositoryFailure && error.kind != FailureKind.transient;
          final delay = Duration(
            seconds: min(300, 1 << min(attempt, 8)) + _random.nextInt(5),
          );
          await _serial(
            () => _replace(
              OutboxEntry(
                command: entry.command,
                state: permanent ? DraftState.blocked : DraftState.pending,
                attempts: attempt,
                nextAttemptAt: permanent ? null : _clock().add(delay),
                error: error is RepositoryFailure
                    ? error.message
                    : permanent
                    ? 'The receipt needs review. Your local inspection is retained.'
                    : 'Connection interrupted. Your inspection is saved; retry when online.',
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

  Future<void> clear() => _serial(() async {
    await store.remove(storageKey);
    _entries = [];
    notifyListeners();
  });
}
