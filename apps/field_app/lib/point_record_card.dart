import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'plain_language.dart';

/// What a resident learns from a public water point record, in plain words:
/// which point it is, what happened, what happens next, and what the record
/// cannot tell them. Everything shown comes from the loaded records.
class PointRecordCard extends StatelessWidget {
  const PointRecordCard({
    super.key,
    required this.point,
    required this.dashboard,
    this.onOpen,
    this.actions = const [],
  });
  final SamplingPoint point;
  final DashboardSnapshot dashboard;
  final VoidCallback? onOpen;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final asset = dashboard.assets
        .where((a) => a.id == point.assetId)
        .firstOrNull;
    final tasks = dashboard.inspections.where(
      (t) => t.assetId == point.assetId,
    );
    final received = tasks.where((t) => t.isSubmitted).toList()
      ..sort((a, b) => b.submittedAt!.compareTo(a.submittedAt!));
    final upcoming = tasks.where((t) => !t.isSubmitted).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final cases =
        dashboard.cases.where((c) => c.pointLabel == point.label).toList()
          ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    final openCase = cases
        .where((c) => c.state != IncidentState.resolved)
        .firstOrNull;
    final latestInspection = received.firstOrNull?.submittedAt;
    final latestCase = cases.firstOrNull;
    final caseIsLatest =
        latestCase != null &&
        (latestInspection == null ||
            latestCase.reportedAt.isAfter(latestInspection));

    final String happened;
    final String evidence;
    final DateTime? latest;
    if (caseIsLatest) {
      happened = caseOrigin(latestCase);
      evidence = sourceName(latestCase.source);
      latest = latestCase.reportedAt;
    } else if (latestInspection != null) {
      happened =
          'An inspector checked this point on ${recordDate(latestInspection)}.';
      evidence = sourceName(EvidenceSource.inspection);
      latest = latestInspection;
    } else {
      happened = 'No records have been shared for this point yet.';
      evidence = 'None yet';
      latest = null;
    }
    final String next;
    if (openCase != null) {
      final due = openCase.dueAt;
      next =
          '${caseNextStep(openCase.state)}${due == null ? '' : ' Response due ${recordDate(due)}.'}';
    } else if (upcoming.isNotEmpty) {
      final due = upcoming.first.dueAt;
      next = due.isBefore(dashboard.asOf)
          ? 'An inspection was due ${recordDate(due)} and is still to be done.'
          : 'The next inspection is due ${recordDate(due)}.';
    } else {
      next = 'Nothing is scheduled yet.';
    }

    return RecordCard(
      art: LayeredRecordArt(
        type: asset?.type,
        label: 'PUBLIC RECORD',
        caption: latest == null ? null : recordDate(latest),
        height: 150,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('Your water point'),
          const SizedBox(height: 4),
          Text(point.label, style: textTheme.headlineSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              MetaLine(TankMeta.mapPin, dashboard.facility.label),
              if (asset != null)
                MetaLine(TankMeta.connected, assetTypeName(asset.type)),
            ],
          ),
          const SizedBox(height: 16),
          _Answer(
            question: 'What happened?',
            answer: happened,
            accent: caseIsLatest
                ? sourceAccent(latestCase.source)
                : TankAccents.inspection,
            background: TankColors.mint,
            foreground: TankColors.tealDeep,
          ),
          const SizedBox(height: 10),
          _Answer(
            question: 'What happens next?',
            answer: next,
            accent: openCase != null
                ? TankAccents.waiting
                : TankAccents.scheduled,
            background: openCase != null
                ? TankColors.caution
                : const Color(0xFFE4ECF8),
            foreground: openCase != null
                ? TankColors.amber
                : const Color(0xFF2B5687),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Fact(
                label: 'Latest record',
                value: latest == null ? 'None yet' : recordDate(latest),
                icon: TankMeta.calendar,
              ),
              _Fact(
                label: 'Evidence type',
                value: evidence,
                icon: TankMeta.source,
              ),
            ],
          ),
          if (onOpen != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onOpen,
              style: FilledButton.styleFrom(backgroundColor: TankColors.navy),
              icon: const Icon(Symbols.arrow_forward_rounded),
              label: const Text('View record and next steps'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'An inspection records what was seen. It does not show whether the water is safe to drink.',
            style: textTheme.bodySmall,
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.question,
    required this.answer,
    required this.accent,
    required this.background,
    required this.foreground,
  });
  final String question;
  final String answer;
  final DuotoneGlyph accent;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: LeadingRow(
      gap: 12,
      leading: DuotoneIcon(accent, size: 26, color: foreground),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(question, color: foreground),
          const SizedBox(height: 4),
          Text(answer, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      MetaLine(icon, label),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.titleSmall),
    ],
  );
}
