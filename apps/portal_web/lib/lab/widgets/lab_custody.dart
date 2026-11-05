import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_localization/localization.dart';

class LabCustodyTimeline extends StatelessWidget {
  const LabCustodyTimeline({
    super.key,
    required this.record,
    required this.timezone,
  });
  final LabRecord record;
  final String timezone;
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Chain of custody', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Original identities, handoffs and intake decisions remain in the record.',
          style: TextStyle(color: TankColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        LabTimelineEvent(
          title: 'Sample collected',
          detail: 'Collector ${record.sample.collectorId}',
          at: record.sample.collectedAt,
          timezone: timezone,
        ),
        for (final event in record.custody)
          LabTimelineEvent(
            title: 'Laboratory handoff',
            detail: '${event.fromActor}\nTo ${event.toActor}\n${event.note}',
            at: event.occurredAt,
            timezone: timezone,
          ),
        for (final event in record.audit.where(
          (e) => e.to == 'valid' || e.to == 'rejected',
        ))
          LabTimelineEvent(
            title: event.to == 'valid'
                ? 'Accepted for testing'
                : 'Sample rejected',
            detail:
                '${event.reason}\nReviewer ${event.actorId ?? 'Unrecorded'}',
            at: event.at,
            timezone: timezone,
          ),
        if (record.custody.isEmpty)
          const Text(
            'No laboratory handoff recorded yet.',
            style: TextStyle(color: TankColors.muted),
          ),
      ],
    ),
  );
}

class LabTimelineEvent extends StatelessWidget {
  const LabTimelineEvent({
    super.key,
    required this.title,
    required this.detail,
    required this.at,
    required this.timezone,
  });
  final String title;
  final String detail;
  final DateTime at;
  final String timezone;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.radio_button_checked,
            size: 18,
            color: TankColors.teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                recordTime(at, timezone: timezone),
                style: const TextStyle(color: TankColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SelectableText(detail, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  );
}
