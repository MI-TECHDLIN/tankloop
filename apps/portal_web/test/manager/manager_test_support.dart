import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/manager_approvals.dart';
import 'package:tankloop_portal/manager_controller.dart';
import 'package:tankloop_portal/manager_facilities.dart';
import 'package:tankloop_portal/manager_incidents.dart';
import 'package:tankloop_portal/manager_inspections.dart';
import 'package:tankloop_portal/manager_overview.dart';
import 'package:tankloop_portal/manager_reports.dart';
import 'package:tankloop_portal/manager_samples.dart';
import 'package:tankloop_portal/manager_settings.dart';
import 'package:tankloop_portal/manager_team.dart';

final managerNow = DateTime.utc(2026, 11, 15, 12);

TestManagerRepository managerScenario(bool Function(SimulationEngine) ready) {
  final repository = TestManagerRepository(day: 0, connected: false);
  for (var hour = 0; hour < 24 * 30; hour++) {
    if (ready(repository.engine)) return repository;
    repository.engine.advance(const Duration(hours: 1));
  }
  throw StateError('The seeded engine did not reach the required scenario.');
}

typedef RecordedManagerCommand = ({
  String action,
  String id,
  int? version,
  Map<String, Object?> payload,
  String reason,
});

/// Real generated records and domain commands, with controllable service faults.
class TestManagerRepository extends SimulationManagerRepository {
  TestManagerRepository({
    DateTime Function()? clock,
    this.connected = true,
    super.day,
  }) : super(clock: clock ?? (() => managerNow));
  final bool connected;
  @override
  bool get serverBacked => connected;
  Future<ManagerWorkspace> Function(String?)? onLoad;
  Future<int> Function(RecordedManagerCommand)? onCommand;
  final loads = <String?>[];
  final commands = <RecordedManagerCommand>[];

  @override
  Future<ManagerWorkspace> load({String? facilityId}) {
    loads.add(facilityId);
    return onLoad?.call(facilityId) ??
        super.load(
          facilityId:
              facilityId ??
              engine.workOrders.values.firstOrNull?.scope.facilityId,
        );
  }

  @override
  Future<int> transitionIncident({
    required String id,
    required IncidentState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  }) {
    final command = (
      action: wireName(target),
      id: id,
      version: expectedVersion,
      payload: payload,
      reason: reason,
    );
    commands.add(command);
    return onCommand?.call(command) ??
        super.transitionIncident(
          id: id,
          target: target,
          expectedVersion: expectedVersion,
          payload: payload,
          reason: reason,
        );
  }

  @override
  Future<int> transitionWorkOrder({
    required String id,
    required WorkOrderState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  }) {
    final command = (
      action: wireName(target),
      id: id,
      version: expectedVersion,
      payload: payload,
      reason: reason,
    );
    commands.add(command);
    return onCommand?.call(command) ??
        super.transitionWorkOrder(
          id: id,
          target: target,
          expectedVersion: expectedVersion,
          payload: payload,
          reason: reason,
        );
  }

  @override
  Future<int> escalateIncident({
    required String id,
    required int expectedVersion,
    required String reason,
  }) {
    final command = (
      action: 'escalate',
      id: id,
      version: expectedVersion,
      payload: <String, Object?>{},
      reason: reason,
    );
    commands.add(command);
    return onCommand?.call(command) ??
        super.escalateIncident(
          id: id,
          expectedVersion: expectedVersion,
          reason: reason,
        );
  }

  @override
  Future<int> publishResult({
    required String id,
    required int expectedVersion,
    required String reason,
  }) {
    final command = (
      action: 'publish',
      id: id,
      version: expectedVersion,
      payload: <String, Object?>{},
      reason: reason,
    );
    commands.add(command);
    return onCommand?.call(command) ??
        super.publishResult(
          id: id,
          expectedVersion: expectedVersion,
          reason: reason,
        );
  }

  @override
  Future<void> revokeQr({required String token, required String reason}) async {
    final command = (
      action: 'revoke',
      id: token,
      version: null,
      payload: <String, Object?>{},
      reason: reason,
    );
    commands.add(command);
    if (onCommand != null) {
      await onCommand!(command);
    } else {
      await super.revokeQr(token: token, reason: reason);
    }
  }
}

ManagerWorkspace emptyManagerWorkspace(ManagerWorkspace data) =>
    ManagerWorkspace.fromJson({
      'facility': data.facility.toJson(),
      'facilities': data.facilities.map((f) => f.toJson()).toList(),
      'actor_id': data.actorId,
      'as_of': data.asOf.toIso8601String(),
      'fetched_at': data.fetchedAt.toIso8601String(),
      'simulation': {
        'simulation_seed': data.simulationSeed,
        'model_version': data.modelVersion,
      },
      for (final key in [
        'systems',
        'assets',
        'points',
        'templates',
        'inspections',
        'samples',
        'records',
        'incidents',
        'work_orders',
        'memberships',
        'qrs',
        'audit',
      ])
        key: <Map<String, dynamic>>[],
    });

const managerScreenNames = [
  'Overview',
  'Facilities',
  'Incidents',
  'Inspections',
  'Samples',
  'Approvals',
  'Reports',
  'Team',
  'Settings',
];

Widget managerScreen(int index, ManagerController controller) =>
    switch (index) {
      0 => ManagerOverviewScreen(controller: controller),
      1 => ManagerFacilitiesScreen(controller: controller),
      2 => ManagerIncidentsScreen(controller: controller),
      3 => ManagerInspectionsScreen(controller: controller),
      4 => ManagerSamplesScreen(controller: controller),
      5 => ManagerApprovalsScreen(controller: controller),
      6 => ManagerReportsScreen(controller: controller),
      7 => ManagerTeamScreen(controller: controller),
      _ => ManagerSettingsScreen(controller: controller),
    };

Finder managerContent(int index, ManagerWorkspace data) => switch (index) {
  0 => find.text('Evidence completeness'),
  1 => find.byKey(ValueKey('asset-${data.assets.first.id}')),
  2 => find.byKey(ValueKey('incident-${data.incidents.first.id}')),
  3 => find.byKey(ValueKey('inspection-${data.inspections.first.task.id}')),
  4 => find.byKey(ValueKey('sample-${data.samples.first.sample.id}')),
  5 => find.byKey(ValueKey('work-order-${data.orders.first.id}')),
  6 => find.textContaining(
    'of scheduled inspections have a recorded submission.',
  ),
  7 => find.byKey(ValueKey('member-${data.members.first.id}')),
  _ => find.text('Current actor'),
};

Widget managerTestApp(
  Widget child, {
  ManagerController? controller,
  bool reduceMotion = false,
  double textScale = 1,
  bool scroll = true,
}) => MaterialApp(
  theme: tankLoopTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: _ControllerOwner(
    key: ObjectKey(controller),
    controller: controller,
    child: Scaffold(
      body: scroll
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            )
          : child,
    ),
  ),
);

class _ControllerOwner extends StatefulWidget {
  const _ControllerOwner({
    super.key,
    required this.controller,
    required this.child,
  });
  final ManagerController? controller;
  final Widget child;
  @override
  State<_ControllerOwner> createState() => _ControllerOwnerState();
}

class _ControllerOwnerState extends State<_ControllerOwner> {
  @override
  void dispose() {
    widget.controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> managerTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder managerField(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<ManagerController> openManagerScreen(
  WidgetTester tester,
  TestManagerRepository repository,
  int index, {
  String? facilityId,
}) async {
  final controller = ManagerController(repository, clock: () => managerNow);
  await controller.refresh(facilityId: facilityId);
  await tester.pumpWidget(
    managerTestApp(managerScreen(index, controller), controller: controller),
  );
  await tester.pumpAndSettle();
  return controller;
}

Finder managerChip(String label) => find.widgetWithText(FilterChip, label);
