import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/public_point.dart';

class PublicRepositoryFake extends PublicPointRepository {
  PublicRepositoryFake(this.load);
  Future<PublicPointLookup> Function() load;
  Future<PublicConcernReceipt> Function(PublicConcernSubmission)? send;
  int lookups = 0;
  final commands = <PublicConcernSubmission>[];

  @override
  Future<PublicPointLookup> lookup(String token) {
    lookups++;
    return load();
  }

  @override
  Future<PublicConcernReceipt> submitConcern(PublicConcernSubmission command) {
    commands.add(command);
    return send!(command);
  }
}

SimulationPublicPointRepository simulatedPublic({int day = 10}) =>
    SimulationPublicPointRepository(
      engine: SimulationEngine()..advance(Duration(days: day)),
    );

PublicPointLookup historicalLookup() {
  final engine = SimulationEngine();
  PublicQr? qr;
  for (var hour = 0; hour <= 21 * 24 && qr == null; hour++) {
    engine.advanceTo(engine.startsAt.add(Duration(hours: hour)));
    qr = engine.qrs.where((q) {
      final record = engine.publicRecord(q.token)!;
      return record.state == PublicState.confirmedFinding &&
          record.tests.isNotEmpty;
    }).firstOrNull;
  }
  final issuedQr =
      qr ??
      (throw StateError('The seed must produce an open published finding.'));
  return PublicPointLookup.found(
    projectPublicRecord(
      qr: issuedQr,
      point: engine.points.singleWhere((p) => p.id == issuedQr.pointId),
      facility: engine.facilities.singleWhere(
        (f) => f.id == issuedQr.scope.facilityId,
      ),
      results: engine.results.values,
      incidents: engine.incidents.values,
      workOrders: engine.workOrders.values,
      now: engine.now.add(const Duration(days: 40)),
    )!,
  );
}

Widget publicPage({
  required PublicPointRepository repository,
  required String token,
  bool Function()? online,
  Stream<bool>? connectivity,
  DateTime Function()? clock,
  ValueChanged<String>? onPrint,
  bool textFirst = false,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: tankLoopTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: child!,
  ),
  home: PublicPointPage(
    repository: repository,
    token: token,
    isOnline: online,
    connectivity: connectivity,
    clock: clock,
    onPrint: onPrint,
    initialTextFirst: textFirst,
    baseUri: Uri.parse('https://verify.example.test/demo/'),
  ),
);
