import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'lab_record_widgets.dart';

class LabResultEvidence extends StatelessWidget {
  const LabResultEvidence({
    super.key,
    required this.record,
    required this.timezone,
  });
  final LabRecord record;
  final String timezone;
  @override
  Widget build(BuildContext context) {
    final reading = record.measurement;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reported evidence',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (reading == null)
            const Text(
              'No measurement entered. A missing result is not a negative result.',
            )
          else ...[
            Text(
              reading.indicator.label,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              reading.unit == ResultUnit.presenceAbsence
                  ? '${reading.detected ? 'Present' : 'Absent'} · ${reading.unit.label}'
                  : '${labNumber(reading.value)} ${reading.unit.label}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Detection limit: ${labNumber(reading.detectionLimit)} ${reading.unit.label}',
            ),
            const SizedBox(height: 12),
            Text(
              reading.method,
              style: const TextStyle(color: TankColors.muted),
            ),
            if (reading.indicator == Indicator.hydrogenSulfide) ...[
              const SizedBox(height: 12),
              Text(
                'H₂S screening indicator ${reading.detected ? 'detected' : 'not detected'} in this sample on ${isoDate(record.sample.collectedAt)}. This does not establish E. coli presence or absence.',
              ),
            ],
            if (record.isReviewed &&
                reading.indicator == Indicator.eColi &&
                !reading.detected) ...[
              const SizedBox(height: 12),
              Text(
                'No E. coli detected in this sample on ${isoDate(record.sample.collectedAt)}; other hazards were not assessed.',
              ),
            ],
            if (!record.isReviewed && !record.isHistorical) ...[
              const SizedBox(height: 12),
              const Text(
                'Lab-uploaded · Authorized review pending',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
          const Divider(height: 32),
          for (final item in [
            ('Collected', record.sample.collectedAt),
            ('Received', record.receivedAt),
            ('Tested', record.testedAt),
            ('Reviewed', record.reviewedAt),
            ('Published', record.publishedAt),
          ])
            LabDetail(
              item.$1,
              item.$2 == null
                  ? 'Not recorded'
                  : recordTime(item.$2!, timezone: timezone),
            ),
          if (record.reviewedBy != null)
            LabDetail('Reviewer', record.reviewedBy!),
          if (record.reportRef != null) ...[
            LabDetail('Signed report reference', record.reportRef!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: record.reportRef!),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Signed report reference copied'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy report reference'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            PublicWaterRecord.limitation,
            style: TextStyle(fontSize: 13, color: TankColors.muted),
          ),
        ],
      ),
    );
  }
}
