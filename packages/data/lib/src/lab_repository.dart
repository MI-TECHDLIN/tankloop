import 'package:tankloop_domain/domain.dart';
import 'lab_models.dart';
import 'repository.dart';

abstract interface class LabRepository {
  bool get serverBacked;
  Future<LabWorkspace> load({String? facilityId});
  Future<LabReceipt> submit(LabCommand command);
}

class LabConnectionFailure extends RepositoryFailure {
  const LabConnectionFailure()
    : super(
        FailureKind.transient,
        'The lab service could not be reached. Reconnect and refresh before making a decision.',
      );
}

/// Uses the same seeded event engine as Field and Verify. Local demonstration
/// playback is read-only: it cannot manufacture an attestation receipt.
class SimulationLabRepository implements LabRepository {
  SimulationLabRepository({
    SimulationEngine? engine,
    int seed = 20261101,
    int day = 10,
    DateTime Function()? clock,
  }) : engine =
           engine ??
           (SimulationEngine(seed: seed)..advance(Duration(days: day))),
       clock = clock ?? DateTime.now;
  final SimulationEngine engine;
  final DateTime Function() clock;
  @override
  bool get serverBacked => false;

  @override
  Future<LabWorkspace> load({String? facilityId}) async {
    final facility = facilityId == null
        ? engine.facilities.first
        : engine.facilities.where((f) => f.id == facilityId).firstOrNull;
    if (facility == null) {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Facility unavailable.',
      );
    }
    return LabWorkspace.fromJson({
      'facility': facility.toJson(),
      'facilities': engine.facilities.map((f) => f.toJson()).toList(),
      'actor_id': engine.actorFor(facility.scope, Role.lab).id,
      'as_of': engine.now.toIso8601String(),
      'fetched_at': clock().toUtc().toIso8601String(),
      'simulation': {'simulation_seed': engine.seed, 'model_version': 1},
      'records':
          engine.results.values
              .where((r) => r.sample.scope.matches(facility.scope))
              .map(
                (r) => {
                  ...r.toJson(),
                  'sample': {
                    ...r.sample.toJson(),
                    'preservation_note':
                        'Simulated sealed container and transport record; not a real sample.',
                  },
                  'point_label': engine.points
                      .singleWhere((p) => p.id == r.sample.pointId)
                      .label,
                  'open_incident_count': engine.incidents.values
                      .where(
                        (i) =>
                            i.scope.matches(facility.scope) &&
                            i.pointIds.contains(r.sample.pointId) &&
                            i.isOpen,
                      )
                      .length,
                  'custody': engine.custody
                      .where((c) => c.sampleId == r.sample.id)
                      .map((c) => c.toJson())
                      .toList(),
                  'audit': r.history.map((a) => a.toJson()).toList(),
                },
              )
              .toList()
            ..sort(
              (a, b) => ((b['sample'] as Map)['collected_at'] as String)
                  .compareTo((a['sample'] as Map)['collected_at'] as String),
            ),
    });
  }

  @override
  Future<LabReceipt> submit(
    LabCommand command,
  ) async => throw const RepositoryFailure(
    FailureKind.permission,
    'A connected Supabase lab session is required. Standalone playback cannot attest or revise a result.',
  );
}
