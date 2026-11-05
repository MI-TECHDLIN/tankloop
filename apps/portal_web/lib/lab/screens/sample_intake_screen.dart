import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import '../lab_controller.dart';
import '../lab_navigation.dart';
import '../widgets/lab_custody.dart';
import '../widgets/lab_intake_form.dart';
import '../widgets/lab_record_widgets.dart';
import '../widgets/lab_screen_frame.dart';

class LabSampleIntakeScreen extends StatelessWidget {
  const LabSampleIntakeScreen({
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
      : data.activeRecords.where((r) => r.needsIntake).firstOrNull ??
            data.activeRecords.firstOrNull;

  @override
  Widget build(BuildContext context) => LabScreenFrame(
    controller: controller,
    title: 'Sample intake',
    description:
        'Check the physical handoff before accepting a sample into the laboratory record.',
    isEmpty: (data) => _selected(data) == null,
    emptyTitle: recordId == null ? 'No samples received' : 'Sample unavailable',
    emptyMessage:
        'Select an assigned facility or refresh to find its registered samples. A missing sample is not a negative result.',
    builder: (data) {
      final record = _selected(data)!;
      final choices = [...data.activeRecords, if (record.isHistorical) record];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabRecordPicker(
            records: choices,
            selected: record,
            onSelected: (r) => onNavigate(LabSection.intake, r.id),
          ),
          const SizedBox(height: 20),
          LabColumns(
            primary: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabSampleIdentity(
                  record: record,
                  timezone: data.facility.timezone,
                ),
                const SizedBox(height: 20),
                if (record.needsIntake)
                  LabIntakeForm(
                    key: ValueKey(record.id),
                    record: record,
                    controller: controller,
                  )
                else
                  NoticeCard(
                    title: record.state == ResultState.rejected
                        ? 'Rejected at intake'
                        : 'Intake already recorded',
                    message: record.state == ResultState.rejected
                        ? 'No valid result from this sample.'
                        : 'The custody and intake decisions are retained below. Continue with the result record.',
                    icon: record.state == ResultState.rejected
                        ? Icons.block_outlined
                        : Icons.inventory_2_outlined,
                    caution: record.state == ResultState.rejected,
                    action: record.state == ResultState.rejected
                        ? null
                        : TextButton.icon(
                            onPressed: () =>
                                onNavigate(LabSection.results, record.id),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Open result'),
                          ),
                  ),
              ],
            ),
            secondary: LabCustodyTimeline(
              record: record,
              timezone: data.facility.timezone,
            ),
          ),
        ],
      );
    },
  );
}
