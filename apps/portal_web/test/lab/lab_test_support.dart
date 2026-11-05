import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/lab/lab_controller.dart';
import 'package:tankloop_portal/lab/lab_navigation.dart';
import 'package:tankloop_portal/lab/screens/inbox_screen.dart';
import 'package:tankloop_portal/lab/screens/results_screen.dart';
import 'package:tankloop_portal/lab/screens/revisions_screen.dart';
import 'package:tankloop_portal/lab/screens/sample_intake_screen.dart';

final labNow = DateTime.utc(2026, 11, 15, 12);

/// Exercise actual generated lifecycle states instead of a static UI carousel.
Future<LabWorkspace> generatedLabWorkspace({
  ResultState? state,
  String? recordId,
  bool empty = false,
}) async {
  final repository = SimulationLabRepository(
    day: state == null && !empty ? 10 : 0,
    clock: () => labNow,
  );
  if (state != null) {
    final facility = repository.engine.facilities.first;
    for (var hour = 0; hour < 500; hour++) {
      if (repository.engine.results.values.any(
        (r) =>
            r.sample.scope.matches(facility.scope) &&
            r.state == state &&
            (recordId == null || r.id == recordId),
      )) {
        return repository.load();
      }
      repository.engine.advance(const Duration(hours: 1));
    }
    throw StateError('The seeded timeline did not reach ${state.name}.');
  }
  return repository.load();
}

class TestLabRepository implements LabRepository {
  TestLabRepository(this.workspace, {this.serverBacked = true});
  LabWorkspace workspace;
  @override
  final bool serverBacked;
  Future<LabWorkspace> Function(String?)? onLoad;
  Future<LabReceipt> Function(LabCommand)? onSubmit;
  final commands = <LabCommand>[];
  final loads = <String?>[];

  @override
  Future<LabWorkspace> load({String? facilityId}) {
    loads.add(facilityId);
    return onLoad?.call(facilityId) ?? Future.value(workspace);
  }

  @override
  Future<LabReceipt> submit(LabCommand command) {
    commands.add(command);
    return onSubmit?.call(command) ??
        Future.error(
          StateError('No server response configured for this test.'),
        );
  }
}

LabReceipt testReceipt(LabCommand command, LabWorkspace data) =>
    LabReceipt.fromJson({
      'client_event_id': command.eventId,
      'result_id': command.resultId,
      'previous_result_id': command.resultId,
      'action': wireName(command.action),
      'version': command.expectedVersion + 1,
      'state': switch (command.action) {
        LabAction.accept => 'valid',
        LabAction.reject => 'rejected',
        LabAction.enterResult => 'tested',
        LabAction.attest || LabAction.correct => 'reviewed',
      },
      'actor_id': data.actorId,
      'recorded_at': data.asOf.toIso8601String(),
      'is_simulated': true,
    });

Widget labScreen(
  LabSection section,
  LabController controller, {
  String? recordId,
  LabNavigate? onNavigate,
}) {
  void navigate(LabSection section, String? id) =>
      onNavigate?.call(section, id);
  return switch (section) {
    LabSection.inbox => LabInboxScreen(
      controller: controller,
      onNavigate: navigate,
    ),
    LabSection.intake => LabSampleIntakeScreen(
      controller: controller,
      onNavigate: navigate,
      recordId: recordId,
    ),
    LabSection.results => LabResultsScreen(
      controller: controller,
      onNavigate: navigate,
      recordId: recordId,
    ),
    LabSection.revisions => LabRevisionsScreen(
      controller: controller,
      onNavigate: navigate,
      recordId: recordId,
    ),
  };
}

Widget labTestApp(Widget child, {LabController? controller}) => MaterialApp(
  theme: tankLoopTheme(),
  home: _ControllerOwner(
    key: ObjectKey(controller),
    controller: controller,
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);

class _ControllerOwner extends StatefulWidget {
  const _ControllerOwner({
    super.key,
    required this.controller,
    required this.child,
  });
  final LabController? controller;
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
