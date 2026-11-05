import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import '../lab_controller.dart';
import '../lab_navigation.dart';
import '../widgets/lab_record_widgets.dart';
import '../widgets/lab_revision_form.dart';
import '../widgets/lab_revision_history.dart';
import '../widgets/lab_screen_frame.dart';

class LabRevisionsScreen extends StatelessWidget {
  const LabRevisionsScreen({
    super.key,
    required this.controller,
    required this.onNavigate,
    this.recordId,
  });
  final LabController controller;
  final LabNavigate onNavigate;
  final String? recordId;
  List<LabRecord> _current(LabWorkspace data) =>
      data.activeRecords.where((r) => r.isReviewed).toList();
  LabRecord? _selected(LabWorkspace data) {
    if (recordId == null) return _current(data).firstOrNull;
    final requested = data.record(recordId);
    return requested == null
        ? null
        : _current(
            data,
          ).where((r) => r.sample.id == requested.sample.id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) => LabScreenFrame(
    controller: controller,
    title: 'Revisions',
    description:
        'Correct the record without erasing its history. Each change has a reason and an accountable reviewer.',
    isEmpty: (data) => _selected(data) == null,
    emptyTitle: recordId == null
        ? 'No reviewed results to revise'
        : 'Reviewed result unavailable',
    emptyMessage:
        'Only an authorized review with a linked report can have a superseding revision. Pending and rejected samples cannot be revised into verified evidence.',
    builder: (data) {
      final record = _selected(data)!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabRecordPicker(
            records: _current(data),
            selected: record,
            onSelected: (r) => onNavigate(LabSection.revisions, r.id),
          ),
          const SizedBox(height: 20),
          LabSampleIdentity(record: record, timezone: data.facility.timezone),
          const SizedBox(height: 24),
          LabColumns(
            primary: LabRevisionHistory(
              records: data.lineage(record),
              timezone: data.facility.timezone,
            ),
            secondary: LabRevisionForm(
              key: ValueKey(record.id),
              record: record,
              controller: controller,
              onRevised: (id) => onNavigate(LabSection.revisions, id),
            ),
          ),
        ],
      );
    },
  );
}
