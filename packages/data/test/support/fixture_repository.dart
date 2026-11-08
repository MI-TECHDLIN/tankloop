// Test-only backend for durable draft, camera, QR and receipt scenarios.
import 'dart:convert';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';

class FixtureRepository extends TankLoopRepository
    implements FieldWorkRepository {
  FixtureRepository({
    int seed = 20261101,
    int day = 10,
    this.liveRecords = false,
  }) : engine = SimulationEngine(seed: seed)..advance(Duration(days: day));
  final SimulationEngine engine;
  final bool liveRecords;
  final _workReceipts = <String, WorkStepReceipt>{};
  final _workRequests = <String, String>{};
  @override
  Future<WorkStepReceipt> submitWorkStep(WorkStepCommand command) async {
    final prior = _workReceipts[command.clientEventId];
    final content = jsonEncode(command.toJson());
    if (prior != null) {
      requireRule(
        _workRequests[command.clientEventId] == content,
        'event_conflict',
        'Command content changed.',
      );
      return prior;
    }
    final order = engine.workOrders[command.orderId];
    requireRule(
      order != null &&
          order.version == command.expectedVersion &&
          order.scope.matches(command.scope),
      'version_conflict',
      'Refresh this work order before recording another step.',
    );
    final next = order!.transition(
      command.target,
      CommandContext(
        actor: engine.actorFor(order.scope, Role.field),
        at: engine.now,
        eventId: command.clientEventId,
        serverConfirmed: true,
        reason: command.notes.isEmpty
            ? 'Simulated field action'
            : command.notes,
      ),
      evidence: command.notes.isEmpty ? null : command.notes,
      evidenceFiles: command.evidence,
    );
    engine.workOrders[order.id] = next;
    final receipt = WorkStepReceipt(
      clientEventId: command.clientEventId,
      orderId: order.id,
      version: next.version,
      receivedAt: engine.now,
    );
    _workRequests[command.clientEventId] = content;
    _workReceipts[command.clientEventId] = receipt;
    return receipt;
  }

  @override
  Future<DashboardSnapshot> today() async {
    final facility = engine.facilities.first;
    final tasks =
        engine.inspections.values
            .where((t) => t.scope.matches(facility.scope))
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final snapshot = DashboardSnapshot(
      facility: facility,
      actorId: engine.actorFor(facility.scope, Role.field).id,
      asOf: engine.now,
      assets: engine.assets
          .where((a) => a.scope.matches(facility.scope))
          .toList(),
      points: engine.points
          .where((p) => p.scope.matches(facility.scope))
          .toList(),
      templates: engine.templates
          .where((t) => t.scope.matches(facility.scope))
          .toList(),
      inspections: tasks,
      cases: engine.incidents.values
          .where((i) => i.scope.matches(facility.scope))
          .map(
            (i) => CaseSummary(
              id: i.id,
              source: i.source,
              state: i.state,
              pointLabel: engine.points
                  .singleWhere((p) => p.id == i.pointIds.first)
                  .label,
              reportedAt: i.reportedAt,
              dueAt: i.dueAt,
              hasOwner: i.ownerId != null,
              isSimulated: true,
              events: i.history
                  .map((e) => '${isoDate(e.at)} · ${e.to.replaceAll('_', ' ')}')
                  .toList(),
            ),
          )
          .toList(),
      workOrders: engine.workOrders.values
          .where((w) => w.scope.matches(facility.scope))
          .map(
            (w) =>
                FieldWorkOrder.fromJson(Map<String, dynamic>.from(w.toJson())),
          )
          .toList(),
      publicTokens: {
        for (final q in engine.qrs.where(
          (q) => q.scope.matches(facility.scope),
        ))
          q.pointId: q.token,
      },
    );
    if (!liveRecords) return snapshot;
    Object? live(Object? value) => switch (value) {
      Map() => value.map(
        (key, item) =>
            MapEntry(key, key == 'is_simulated' ? false : live(item)),
      ),
      List() => value.map(live).toList(),
      _ => value,
    };
    return DashboardSnapshot.fromJson(
      jsonDecode(jsonEncode(live(snapshot.toJson()))) as Map<String, dynamic>,
    );
  }

  @override
  Future<SyncReceipt> submitInspection(InspectionSubmission command) async {
    try {
      final version = engine.submitInspection(
        InspectionSubmission.fromJson({
          ...command.toJson(),
          'is_simulated': true,
        }),
      );
      return SyncReceipt(
        clientEventId: command.clientEventId,
        inspectionId: command.taskId,
        version: version,
        receivedAt: engine.inspections[command.taskId]!.submittedAt!,
      );
    } on RuleViolation catch (error) {
      throw RepositoryFailure(
        error.code.contains('conflict')
            ? FailureKind.conflict
            : error.code == 'permission_denied'
            ? FailureKind.permission
            : FailureKind.invalid,
        error.message,
      );
    }
  }

  @override
  Future<PublicWaterRecord?> publicRecord(String token) async =>
      engine.publicRecord(token);
}
