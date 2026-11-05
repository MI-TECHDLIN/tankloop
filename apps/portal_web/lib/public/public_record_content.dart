import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'public_concerns.dart';
import 'public_notice.dart';
import 'public_point_controller.dart';
import 'public_status_card.dart';
import 'public_surface.dart';
import 'public_test_card.dart';

class PublicRecordContent extends StatelessWidget {
  const PublicRecordContent({
    super.key,
    required this.controller,
    required this.textFirst,
    required this.onReport,
    required this.onShare,
    required this.onPrint,
    this.simulatedDay,
    this.seed,
    this.onAdvance,
  });
  final PublicPointController controller;
  final bool textFirst;
  final VoidCallback onReport;
  final VoidCallback onShare;
  final VoidCallback onPrint;
  final int? simulatedDay;
  final int? seed;
  final VoidCallback? onAdvance;

  @override
  Widget build(BuildContext context) {
    final data = controller.record!;
    final test = data.latestTest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          data.facilityLabel.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: TankColors.muted,
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            data.pointLabel,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: MediaQuery.sizeOf(context).width < 600 ? 34 : 44,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Match this name to the water point where you scanned the QR.',
          style: TextStyle(color: TankColors.muted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: controller.canReport ? onReport : null,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              label: const Text('Report a concern'),
            ),
            OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.link_rounded, size: 20),
              label: const Text('Share link'),
            ),
            OutlinedButton.icon(
              onPressed: onPrint,
              icon: const Icon(Icons.print_outlined, size: 20),
              label: const Text('Print view'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (controller.refreshing) ...[
          const LinearProgressIndicator(
            semanticsLabel: 'Refreshing public record',
          ),
          const SizedBox(height: 16),
        ],
        if (controller.isSnapshot ||
            controller.phase == PublicPointPhase.offline) ...[
          PublicNotice(
            textFirst: textFirst,
            caution: true,
            title: controller.phase == PublicPointPhase.offline
                ? 'Offline - last loaded record'
                : 'Snapshot not refreshed',
            message:
                'This page may be out of date. The last loaded concerns remain visible below. Refresh before relying on this record or sending a concern.',
            icon: Icons.history_rounded,
            action: TextButton.icon(
              onPressed: controller.refreshing ? null : controller.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh record'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final status = PublicStatusCard(
              record: data,
              textFirst: textFirst,
              isSnapshot: controller.isSnapshot,
            );
            if (constraints.maxWidth < 800 || textFirst) return status;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: status),
                const SizedBox(width: 20),
                const Expanded(
                  flex: 4,
                  child: PublicSurface(
                    textFirst: false,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 150,
                          child: ExcludeSemantics(child: WaterNetworkArtwork()),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'A record for this point.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Evidence and response, with their limits in view.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: TankColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        PublicNotice(
          textFirst: textFirst,
          title: 'One sample has a limited scope',
          message: PublicWaterRecord.limitation,
        ),
        if (!data.isCurrent) ...[
          const SizedBox(height: 16),
          PublicNotice(
            textFirst: textFirst,
            caution: true,
            icon: Icons.schedule_rounded,
            title: 'No valid current data',
            message:
                'We do not have a current verified test record for this point.',
          ),
          if (test != null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'The published sample below is outdated under the 30-day review window. It remains visible as historical evidence.',
              ),
            ),
        ],
        if (controller.lookup!.hasUnreviewedResults) ...[
          const SizedBox(height: 16),
          PublicNotice(
            textFirst: textFirst,
            title: 'Unverified records are awaiting review',
            message:
                'A field observation or an unreviewed sample is not a verified laboratory finding.',
            icon: Icons.pending_actions_outlined,
          ),
        ],
        const SectionHeading('Last verified record'),
        if (test == null)
          PublicNotice(
            textFirst: textFirst,
            title: 'No reviewed result to show',
            message:
                'A field observation or an unreviewed sample is not a verified laboratory finding.',
            icon: Icons.science_outlined,
          )
        else
          PublicTestCard(
            test: test,
            timezone: data.timezone,
            historical: !data.isCurrent,
            textFirst: textFirst,
          ),
        const SizedBox(height: 16),
        PublicNotice(
          textFirst: textFirst,
          title: 'Evidence freshness',
          icon: Icons.schedule_rounded,
          message: [
            '${data.isSimulated ? 'Simulated record clock' : 'Record checked'}: ${recordTime(data.updatedAt, timezone: data.timezone)}',
            if (test != null)
              'Sample age at that clock: ${data.updatedAt.difference(test.collectedAt).inDays} days.',
            data.isSimulated
                ? 'The 30-day demonstration review window is a demo policy, not an approved monitoring schedule.'
                : 'The current record service uses a 30-day review window.',
            'Currentness is not proof of continuing water quality. A refresh is not a new sample.',
          ].join('\n'),
        ),
        SectionHeading('Open concerns (${data.concerns.length})'),
        PublicConcerns(record: data, textFirst: textFirst),
        if (data.tests.length > 1) ...[
          const SectionHeading('Published test history'),
          PublicSurface(
            textFirst: textFirst,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('${data.tests.length - 1} earlier sample records'),
              subtitle: const Text('Historical evidence stays visible.'),
              children: [
                for (final earlier in data.tests.skip(1))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: PublicTestCard(
                      test: earlier,
                      timezone: data.timezone,
                      historical: true,
                      textFirst: textFirst,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        PublicNotice(
          textFirst: textFirst,
          title: 'Something different at this water point?',
          message:
              'You can report a concern without leaving contact details. Reports are unverified and reviewed separately from laboratory evidence. Private descriptions and contact details are never shown here.',
          icon: Icons.chat_bubble_outline_rounded,
          action: TextButton(
            onPressed: controller.canReport ? onReport : null,
            child: const Text('Report a concern'),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Loaded on this device: ${recordTime(controller.loadedAt!, timezone: data.timezone)}',
          style: const TextStyle(fontSize: 12, color: TankColors.muted),
        ),
        if (seed != null && simulatedDay != null) ...[
          const SizedBox(height: 12),
          Text(
            'Seed $seed · Day $simulatedDay · Deterministic, generated timeline',
            style: const TextStyle(fontSize: 12, color: TankColors.muted),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAdvance,
              icon: const Icon(Icons.fast_forward_outlined),
              label: const Text('Advance 1 day'),
            ),
          ),
        ],
      ],
    );
  }
}
