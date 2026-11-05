import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test(
    'lab playback reads the seeded engine with full scoped provenance',
    () async {
      final now = DateTime.utc(2026, 11, 15);
      final engine = SimulationEngine(seed: 20261101)
        ..advance(const Duration(days: 10));
      final repository = SimulationLabRepository(
        engine: engine,
        clock: () => now,
      );
      final workspace = await repository.load();
      expect(repository.serverBacked, false);
      expect(workspace.facility.id, engine.facilities.first.id);
      expect(workspace.records, isNotEmpty);
      expect(workspace.asOf, engine.now);
      expect(workspace.fetchedAt, now);
      expect(workspace.simulationSeed, engine.seed);
      expect(workspace.modelVersion, 1);
      for (final row in workspace.records) {
        final original = engine.results[row.id]!;
        expect(row.sample.scope.matches(workspace.facility.scope), true);
        expect(row.sample.isSimulated, true);
        expect(row.sample.code, original.sample.code);
        expect(row.state, original.state);
        expect(row.measurement?.toJson(), original.measurement?.toJson());
        expect(row.reportRef, original.reportRef);
        expect(row.reviewedBy, original.reviewedBy);
        expect(row.audit.map((a) => a.id), original.history.map((a) => a.id));
        expect(
          row.custody.map((c) => c.id),
          engine.custody
              .where((c) => c.sampleId == row.sample.id)
              .map((c) => c.id),
        );
      }
      final other = await repository.load(
        facilityId: engine.facilities.last.id,
      );
      expect(
        other.records.every(
          (r) => r.sample.scope.matches(other.facility.scope),
        ),
        true,
      );
      expect(
        other.records
            .map((r) => r.id)
            .toSet()
            .intersection(workspace.records.map((r) => r.id).toSet()),
        isEmpty,
      );
    },
  );

  test(
    'standalone playback cannot mint receipts for any lab command',
    () async {
      final repository = SimulationLabRepository();
      final workspace = await repository.load();
      final before = workspace.records
          .map((r) => (r.id, r.version, r.state))
          .toList();
      for (final action in LabAction.values) {
        await expectLater(
          repository.submit(
            LabCommand(
              eventId: 'simulation-must-not-submit',
              resultId: workspace.records.first.id,
              expectedVersion: workspace.records.first.version,
              action: action,
              payload: const {},
              reason: 'Attempted local command',
            ),
          ),
          throwsA(
            isA<RepositoryFailure>().having(
              (e) => e.kind,
              'kind',
              FailureKind.permission,
            ),
          ),
        );
      }
      expect(
        (await repository.load()).records
            .map((r) => (r.id, r.version, r.state))
            .toList(),
        before,
      );
      await expectLater(
        repository.load(facilityId: 'not-assigned'),
        throwsA(isA<RepositoryFailure>()),
      );
    },
  );

  test(
    'revision ancestry orders equal-clock corrections and retains earlier evidence',
    () async {
      final repository = SimulationLabRepository();
      final engine = repository.engine;
      final original = engine.results.values.firstWhere(
        (r) =>
            r.isReviewed &&
            r.sample.scope.matches(engine.facilities.first.scope),
      );
      final reading = original.measurement!;
      CommandContext context(String id) => CommandContext(
        actor: engine.actorFor(original.sample.scope, Role.lab),
        at: engine.now,
        eventId: id,
        serverConfirmed: true,
        reason: 'SIMULATED correction of transcription',
      );
      final first = original.correct(
        newId: 'first-revision',
        reading: Measurement(
          indicator: reading.indicator,
          method: reading.method,
          value: 5,
          unit: reading.unit,
          detectionLimit: .5,
        ),
        linkedReport: 'simulation://reports/first-revision',
        context: context('first-correction'),
      );
      final second = first.replacement.correct(
        newId: 'second-revision',
        reading: Measurement(
          indicator: reading.indicator,
          method: reading.method,
          value: 7,
          unit: reading.unit,
          detectionLimit: .25,
        ),
        linkedReport: 'simulation://reports/second-revision',
        context: context('second-correction'),
      );
      engine.results[original.id] = first.original;
      // The server may return equal-clock revisions in arbitrary ID order.
      engine.results[second.replacement.id] = second.replacement;
      engine.results[second.original.id] = second.original;
      final workspace = await repository.load();
      final lineage = workspace.lineage(
        workspace.record(second.replacement.id)!,
      );
      expect(lineage.map((r) => r.id), [
        original.id,
        first.replacement.id,
        second.replacement.id,
      ]);
      expect(lineage.first.measurement!.toJson(), reading.toJson());
      expect(lineage.first.reportRef, original.reportRef);
      expect(lineage.first.reviewedAt, original.reviewedAt);
      expect(lineage.first.reviewedBy, original.reviewedBy);
      expect(
        lineage[1].correctionReason,
        'SIMULATED correction of transcription',
      );
      expect(
        lineage[1].correctedBy,
        engine.actorFor(original.sample.scope, Role.lab).id,
      );
      expect(lineage[1].correctedAt, engine.now);
      expect(lineage.last.measurement!.detectionLimit, .25);
      expect(
        workspace.activeRecords
            .where((r) => r.sample.id == original.sample.id)
            .single
            .id,
        second.replacement.id,
      );
    },
  );
}
