import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'manager_controller.dart';
import 'manager_screen_states.dart';
import 'manager_widgets.dart';

enum _SampleFilter { all, pending, reviewed, rejected, revisions }

class ManagerSamplesScreen extends StatefulWidget {
  const ManagerSamplesScreen({super.key, required this.controller});
  final ManagerController controller;
  @override
  State<ManagerSamplesScreen> createState() => _ManagerSamplesScreenState();
}

class _ManagerSamplesScreenState extends State<ManagerSamplesScreen> {
  final search = TextEditingController();
  _SampleFilter filter = _SampleFilter.all;
  String? selectedId;
  String? resultId;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void clear() => setState(() {
    search.clear();
    filter = _SampleFilter.all;
    selectedId = null;
    resultId = null;
  });

  @override
  Widget build(BuildContext context) => ManagerScreenFrame(
    title: 'Samples & Results',
    controller: widget.controller,
    isEmpty: (data) => data.samples.isEmpty,
    emptyMessage:
        'No samples are registered for this facility. A missing sample is not a negative result.',
    builder: (context, data) {
      final query = search.text.trim().toLowerCase();
      final samples = data.samples.where((item) {
        final sample = item.sample;
        final result = data.currentResult(sample.id);
        return '${sample.code} ${sample.id} ${data.point(sample.pointId)?.label ?? ''}'
                .toLowerCase()
                .contains(query) &&
            switch (filter) {
              _SampleFilter.all => true,
              _SampleFilter.pending => result == null || result.needsAttention,
              _SampleFilter.reviewed => result?.isReviewed ?? false,
              _SampleFilter.rejected => result?.state == ResultState.rejected,
              _SampleFilter.revisions =>
                data.resultsFor(sample.id).any((r) => r.isHistorical),
            };
      }).toList();
      final selected = samples
          .where((s) => s.sample.id == selectedId)
          .firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'A test describes one sample, at one point, at one time. It does not establish the safety of the whole water system.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search sample codes or points',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _SampleFilter.values)
                FilterChip(
                  label: Text(humanState(value.name)),
                  selected: filter == value,
                  onSelected: (_) => setState(() => filter = value),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (samples.isEmpty)
            ManagerNoMatches(onClear: clear)
          else
            ManagerRecordLayout(
              onClose: () => setState(() {
                selectedId = null;
                resultId = null;
              }),
              list: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in samples)
                    ManagerRecordTile(
                      key: ValueKey('sample-${item.sample.id}'),
                      title: item.sample.code,
                      subtitle:
                          '${data.point(item.sample.pointId)?.label ?? 'Point unavailable'} · Collected ${recordTime(item.sample.collectedAt, timezone: data.facility.timezone)}',
                      onOpen: () => setState(() {
                        selectedId = item.sample.id;
                        resultId = null;
                      }),
                      selected: selected?.sample.id == item.sample.id,
                      badges: [
                        _stage(data.currentResult(item.sample.id)),
                        StatusPill(
                          '${data.incidents.where((i) => i.isOpen && i.pointIds.contains(item.sample.pointId)).length} open incidents',
                          icon: Icons.flag_outlined,
                        ),
                      ],
                    ),
                ],
              ),
              detail: selected == null ? null : _detail(data, selected),
            ),
        ],
      );
    },
  );

  Widget _stage(LabRecord? result) => StatusPill(
    result == null ? 'No result recorded' : humanState(wireName(result.state)),
    caution:
        result == null ||
        result.state == ResultState.rejected ||
        result.isHistorical,
    icon: Icons.science_outlined,
  );

  Widget _detail(ManagerWorkspace data, ManagerSample item) {
    final sample = item.sample;
    final records = data.resultsFor(sample.id);
    final result =
        records.where((r) => r.id == resultId).firstOrNull ??
        data.currentResult(sample.id) ??
        records.firstOrNull;
    String time(DateTime? value) => value == null
        ? 'Not recorded'
        : recordTime(value, timezone: data.facility.timezone);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(sample.code, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          ManagerDetail('Sample ID', sample.id),
          ManagerDetail(
            'Sampling point',
            data.point(sample.pointId)?.label ?? sample.pointId,
          ),
          ManagerDetail('Collected', time(sample.collectedAt)),
          ManagerDetail('Collector', sample.collectorId),
          ManagerDetail('Planned method', sample.intendedMethod),
          ManagerDetail('Preservation and transport', item.preservationNote),
          const SectionHeading('Custody'),
          if (item.custody.isEmpty) const Text('No custody handoff recorded.'),
          for (final event in item.custody) ...[
            ManagerDetail('Handoff time', time(event.occurredAt)),
            ManagerDetail('From actor', event.fromActor),
            ManagerDetail('To actor', event.toActor),
            ManagerDetail('Custody note', event.note),
          ],
          const SectionHeading('Result and revisions'),
          if (result == null)
            const Text('No result has been recorded for this sample.'),
          if (result != null) ...[
            DropdownButtonFormField<String>(
              key: ValueKey(result.id),
              initialValue: result.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Result revision'),
              items: [
                for (final revision in records)
                  DropdownMenuItem(
                    value: revision.id,
                    child: Text(
                      '${revision.id.substring(0, 8)} · ${humanState(wireName(revision.state))}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(() => resultId = id),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _stage(result),
                StatusPill('Source: ${humanState(wireName(result.source))}'),
                if (result.isReviewed)
                  StatusPill(
                    sample.isSimulated
                        ? 'Simulated lab review'
                        : 'Independently reviewed',
                  ),
                if (result.source == EvidenceSource.fieldScreen)
                  const StatusPill(
                    'Field-screened, not independent review',
                    caution: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (result.state == ResultState.rejected)
              NoticeCard(
                title: 'No valid result from this sample.',
                message: result.rejectionReason ?? 'Intake was rejected.',
                caution: true,
              ),
            if (result.isHistorical)
              const NoticeCard(
                title: 'Superseded result',
                message:
                    'Historical evidence retained for audit. Use the current revision when reviewing follow-up.',
                caution: true,
              ),
            ManagerDetail('Result ID', result.id),
            if (result.measurement case final measurement?) ...[
              ManagerDetail('Indicator', measurement.indicator.label),
              ManagerDetail('Reported method', measurement.method),
              ManagerDetail(
                'Reported value${result.isReviewed ? '' : ' (not current reviewed evidence)'}',
                '${measurement.value} ${measurement.unit.label}',
              ),
              ManagerDetail(
                'Detection limit',
                '${measurement.detectionLimit} ${measurement.unit.label}',
              ),
              if (measurement.indicator == Indicator.hydrogenSulfide)
                const Text(
                  'H₂S screening does not establish E. coli presence or absence.',
                ),
            ],
            ManagerDetail('Received', time(result.receivedAt)),
            ManagerDetail('Tested', time(result.testedAt)),
            ManagerDetail('Reviewed', time(result.reviewedAt)),
            ManagerDetail('Published', time(result.publishedAt)),
            ManagerDetail('Reviewer', result.reviewedBy ?? 'Not reviewed'),
            ManagerDetail(
              'Report reference',
              result.reportRef ?? 'No report linked',
            ),
            if (result.revisionOf != null) ...[
              ManagerDetail('Revises result', result.revisionOf!),
              ManagerDetail(
                'Correction reason',
                result.correctionReason ?? 'Not recorded',
              ),
              ManagerDetail(
                'Corrected by',
                result.correctedBy ?? 'Not recorded',
              ),
              ManagerDetail('Corrected at', time(result.correctedAt)),
            ],
            if (result.state == ResultState.reviewed && result.isReviewed)
              FilledButton(
                onPressed: !widget.controller.canWrite
                    ? null
                    : () async {
                        final reason = await managerReason(
                          context,
                          title: 'Publish reviewed result',
                          message:
                              'Publish this dated, scope-limited reviewed record. Outstanding concerns remain visible.',
                          action: 'Publish result',
                        );
                        if (reason == null) return;
                        await widget.controller.act(
                          () => widget.controller.repository.publishResult(
                            id: result.id,
                            expectedVersion: result.version,
                            reason: reason,
                          ),
                          'Reviewed result published.',
                          basedOn: data,
                        );
                      },
                child: const Text('Publish reviewed result'),
              ),
            ManagerAuditTrail(
              events: data.auditFor(result.id),
              timezone: data.facility.timezone,
            ),
          ],
          if (data.incidents.any(
            (i) => i.pointIds.contains(sample.pointId) && i.isOpen,
          ))
            ManagerIncidentList(
              incidents: data.incidents
                  .where((i) => i.pointIds.contains(sample.pointId) && i.isOpen)
                  .toList(),
              controller: widget.controller,
              data: data,
            ),
        ],
      ),
    );
  }
}
