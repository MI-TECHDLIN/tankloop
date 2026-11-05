import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import '../lab_controller.dart';
import '../lab_navigation.dart';
import '../widgets/lab_attestation_form.dart';
import '../widgets/lab_record_widgets.dart';
import '../widgets/lab_result_evidence.dart';
import '../widgets/lab_result_form.dart';
import '../widgets/lab_screen_frame.dart';

class LabResultsScreen extends StatelessWidget {
  const LabResultsScreen({
    super.key,
    required this.controller,
    required this.onNavigate,
    this.recordId,
  });
  final LabController controller;
  final LabNavigate onNavigate;
  final String? recordId;
  LabRecord? _selected(LabWorkspace data) => recordId != null
      ? data.record(recordId)
      : data.activeRecords
                .where((r) => r.state == ResultState.tested)
                .firstOrNull ??
            data.activeRecords
                .where((r) => r.state == ResultState.valid)
                .firstOrNull ??
            data.activeRecords.firstOrNull;

  @override
  Widget build(BuildContext context) => LabScreenFrame(
    controller: controller,
    title: 'Results',
    description:
        'Exact methods, clear units and an accountable review. One sample, at one point, at one time.',
    isEmpty: (data) => _selected(data) == null,
    emptyTitle: recordId == null
        ? 'No result records yet'
        : 'Result unavailable',
    emptyMessage:
        'A registered sample and accepted intake are required before entering laboratory evidence.',
    builder: (data) {
      final record = _selected(data)!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabRecordPicker(
            records: [...data.activeRecords, if (record.isHistorical) record],
            selected: record,
            onSelected: (r) => onNavigate(LabSection.results, r.id),
          ),
          const SizedBox(height: 20),
          LabSampleIdentity(record: record, timezone: data.facility.timezone),
          const SizedBox(height: 20),
          LabColumns(
            primary: LabResultEvidence(
              record: record,
              timezone: data.facility.timezone,
            ),
            secondary: switch (record.state) {
              ResultState.valid => LabResultForm(
                key: ValueKey(record.id),
                record: record,
                controller: controller,
              ),
              ResultState.tested => LabAttestationForm(
                key: ValueKey(record.id),
                record: record,
                controller: controller,
              ),
              ResultState.reviewed ||
              ResultState.published ||
              ResultState.superseded => NoticeCard(
                title: record.isHistorical
                    ? 'Historical result retained'
                    : 'Review recorded',
                message:
                    'Corrections create a superseding revision with a reason, reviewer and timestamp. Publication remains a separate manager decision.',
                icon: Icons.history_rounded,
                action: TextButton.icon(
                  onPressed: () => onNavigate(LabSection.revisions, record.id),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Open revisions'),
                ),
              ),
              ResultState.rejected => const NoticeCard(
                title: 'Sample rejected',
                message: 'No valid result from this sample.',
                caution: true,
              ),
              _ => NoticeCard(
                title: 'Intake required',
                message:
                    'Record the custody handoff and accept or reject the sample before entering a result.',
                action: TextButton(
                  onPressed: () => onNavigate(LabSection.intake, record.id),
                  child: const Text('Open sample intake'),
                ),
              ),
            },
          ),
        ],
      );
    },
  );
}
