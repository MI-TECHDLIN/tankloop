import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_localization/localization.dart';
import 'lab_record_widgets.dart';

class LabRevisionHistory extends StatelessWidget {
  const LabRevisionHistory({
    super.key,
    required this.records,
    required this.timezone,
  });
  final List<LabRecord> records;
  final String timezone;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Preserved result history',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Every earlier result stays visible. A revision does not replace the audit trail.',
        style: TextStyle(color: TankColors.muted),
      ),
      const SizedBox(height: 20),
      for (final (index, record) in records.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  index == 0 ? 'Original result' : 'Revision $index',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LabStagePill(record),
                ),
                const SizedBox(height: 20),
                if (record.measurement case final reading?) ...[
                  Text(
                    '${labNumber(reading.value)} ${reading.unit.label}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${reading.indicator.label} · Detection limit ${labNumber(reading.detectionLimit)} ${reading.unit.label}',
                  ),
                  const SizedBox(height: 20),
                ],
                LabDetail('Result ID', record.id),
                if (record.revisionOf != null)
                  LabDetail('Supersedes', record.revisionOf!),
                LabDetail('Signed report', record.reportRef ?? 'Not recorded'),
                LabDetail('Reviewer', record.reviewedBy ?? 'Not recorded'),
                LabDetail(
                  'Reviewed',
                  record.reviewedAt == null
                      ? 'Not recorded'
                      : recordTime(record.reviewedAt!, timezone: timezone),
                ),
                if (record.correctionReason != null) ...[
                  LabDetail('Correction reason', record.correctionReason!),
                  LabDetail('Correction actor', record.correctedBy!),
                  LabDetail(
                    'Corrected',
                    recordTime(record.correctedAt!, timezone: timezone),
                  ),
                ],
              ],
            ),
          ),
        ),
    ],
  );
}
