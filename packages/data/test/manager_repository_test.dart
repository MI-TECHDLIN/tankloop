import 'package:test/test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';

void main() {
  test('simulation repository routes guarded manager transitions', () async {
    final repository = SimulationRepository(seed: 20261101, day: 10);
    final incident = repository.engine.incidents.values.first;
    await expectLater(
      repository.transitionIncident(
        id: incident.id,
        target: IncidentState.resolved,
        expectedVersion: -1,
        reason: 'premature close',
      ),
      throwsA(isA<RepositoryFailure>()),
    );
    final order = repository.engine.workOrders.values.first;
    await expectLater(
      repository.transitionWorkOrder(
        id: order.id,
        target: WorkOrderState.accepted,
        expectedVersion: -1,
        reason: 'duplicate state',
      ),
      throwsA(isA<RepositoryFailure>()),
    );
  });
}
