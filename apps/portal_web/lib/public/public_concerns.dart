import 'package:flutter/material.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'public_notice.dart';

class PublicConcerns extends StatelessWidget {
  const PublicConcerns({
    super.key,
    required this.record,
    required this.textFirst,
  });
  final PublicWaterRecord record;
  final bool textFirst;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (record.concerns.isEmpty)
        PublicNotice(
          textFirst: textFirst,
          title: 'No open concerns recorded',
          message:
              'This describes the available record. It is not a water-safety certification.',
          icon: Icons.inbox_outlined,
        ),
      for (final concern in record.concerns)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PublicNotice(
            textFirst: textFirst,
            caution: true,
            icon: Icons.flag_outlined,
            title: switch (concern.source) {
              EvidenceSource.residentReport => 'Unverified resident report',
              EvidenceSource.inspection => 'Inspection observation',
              EvidenceSource.fieldScreen => 'Field-screening concern',
              EvidenceSource.laboratory => 'Laboratory-sourced concern',
            },
            message: [
              'Response: ${humanState(wireName(concern.state))}',
              'Reported ${recordTime(concern.reportedAt, timezone: record.timezone)}',
              if (concern.source == EvidenceSource.inspection)
                'Inspection concern reported on ${isoDate(concern.reportedAt)}. Testing may be needed.',
              if (concern.source == EvidenceSource.residentReport)
                'A resident report is not a verified laboratory finding.',
              if (concern.state == IncidentState.verificationPending)
                'Repair recorded; verification is still pending.',
            ].join('\n'),
          ),
        ),
    ],
  );
}
