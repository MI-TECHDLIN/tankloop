import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';

class PublicPointPage extends StatefulWidget {
  const PublicPointPage({
    super.key,
    required this.repository,
    required this.token,
    this.simulatedDay,
    this.seed,
    this.onAdvance,
  });
  final TankLoopRepository repository;
  final String token;
  final int? simulatedDay;
  final int? seed;
  final VoidCallback? onAdvance;
  @override
  State<PublicPointPage> createState() => _PublicPointPageState();
}

class _PublicPointPageState extends State<PublicPointPage> {
  late Future<PublicWaterRecord?> record = widget.repository.publicRecord(
    widget.token,
  );
  bool lowData = false;
  void reload() => setState(() {
    record = widget.repository.publicRecord(widget.token);
  });
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: record,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const RecordUnavailable(
          title: 'Loading the point record',
          message: 'Retrieving a dated record and outstanding concerns.',
          loading: true,
        );
      }
      if (snapshot.hasError) {
        return RecordUnavailable(
          title: 'Live status unavailable',
          message:
              'We could not load the current record. A failed connection does not imply anything about water quality. Check your connection and retry.',
          onRetry: reload,
        );
      }
      if (!snapshot.hasData) {
        return const RecordUnavailable(
          title: 'This point label is unavailable',
          message:
              'The QR may be revoked, replaced, or mistyped. Check the printed point name with the facility manager. No current claim can be made from this link.',
        );
      }
      final data = snapshot.data!;
      return TankBackdrop(
        child: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          const TankBrand(surface: 'VERIFY'),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => lowData = !lowData),
                                icon: Icon(
                                  lowData
                                      ? Icons.view_agenda_outlined
                                      : Icons.text_snippet_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  lowData ? 'Standard view' : 'Text-first view',
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Refresh public record',
                                onPressed: reload,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (data.isSimulated) ...[
                        const SimulationNotice(),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        data.facilityLabel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                          color: TankColors.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data.pointLabel,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'What’s recorded. What’s being done. What we still don’t know.',
                        style: TextStyle(color: TankColors.muted, fontSize: 17),
                      ),
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final status = _status(context, data);
                          final identity = _identity(context, data);
                          if (constraints.maxWidth < 760 || lowData) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                status,
                                const SizedBox(height: 16),
                                if (!lowData) identity,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: status),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: identity),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      const NoticeCard(
                        title: 'One sample has a limited scope',
                        message: PublicWaterRecord.limitation,
                        icon: Icons.info_outline_rounded,
                      ),
                      if (!data.isCurrent) ...[
                        const SizedBox(height: 16),
                        const NoticeCard(
                          title: 'No valid current data',
                          message:
                              'We do not have a current verified test record for this point. Older published records below are historical.',
                          caution: true,
                          icon: Icons.schedule_rounded,
                        ),
                      ],
                      const SectionHeading('Evidence, with the detail'),
                      if (data.latestTest == null)
                        const NoticeCard(
                          title: 'No reviewed result to show',
                          message:
                              'A field observation or an unreviewed sample is not a verified laboratory finding.',
                          icon: Icons.science_outlined,
                        )
                      else
                        _test(
                          context,
                          data.latestTest!,
                          data.timezone,
                          historical: !data.isCurrent,
                        ),
                      SectionHeading(
                        'Open concerns',
                        trailing: StatusPill(
                          '${data.concerns.length} recorded',
                          icon: Icons.flag_outlined,
                          caution: data.concerns.isNotEmpty,
                          compact: true,
                        ),
                      ),
                      if (data.concerns.isEmpty)
                        const NoticeCard(
                          title: 'No open concerns recorded',
                          message:
                              'This describes the available record. It is not a water-safety certification.',
                          icon: Icons.inbox_outlined,
                        ),
                      for (final concern in data.concerns)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.flag_outlined,
                                  color: TankColors.amber,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        humanState(wireName(concern.state)),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${humanState(wireName(concern.source))} · ${recordDate(concern.reportedAt, timezone: data.timezone)}',
                                        style: const TextStyle(
                                          color: TankColors.muted,
                                        ),
                                      ),
                                      if (concern.state ==
                                          IncidentState.verificationPending)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Repair recorded; verification is still pending.',
                                          ),
                                        ),
                                      if (concern.source ==
                                          EvidenceSource.inspection)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Inspection risk observed. No test result is implied.',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (data.tests.length > 1) ...[
                        const SectionHeading('Published test history'),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              '${data.tests.length} dated sample records',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: const Text(
                              'Historical evidence stays visible.',
                            ),
                            children: [
                              for (final test in data.tests.skip(1))
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 12,
                                    bottom: 16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        recordDate(
                                          test.collectedAt,
                                          timezone: data.timezone,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(test.exactFinding),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${test.method} · ${test.units.label}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: TankColors.muted,
                                        ),
                                      ),
                                      const Divider(height: 24),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      NoticeCard(
                        title: 'A concern or a different point label?',
                        message:
                            'Contact the facility’s designated water-operations manager. This demonstration does not send resident reports or external notifications.',
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${data.isSimulated ? 'Simulated record clock' : 'Record checked'}\n${recordTime(data.updatedAt, timezone: data.timezone)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: TankColors.muted,
                            ),
                          ),
                          if (widget.simulatedDay != null)
                            OutlinedButton.icon(
                              onPressed: widget.onAdvance,
                              icon: const Icon(
                                Icons.fast_forward_outlined,
                                size: 18,
                              ),
                              label: const Text('Advance 1 day'),
                            ),
                        ],
                      ),
                      if (widget.seed != null && widget.simulatedDay != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Seed ${widget.seed} · Day ${widget.simulatedDay} · Deterministic, generated timeline',
                            style: const TextStyle(
                              fontSize: 12,
                              color: TankColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _status(BuildContext context, PublicWaterRecord data) {
    final caution = data.concerns.isNotEmpty || !data.isCurrent;
    return GlassCard(
      color: caution
          ? TankColors.caution.withValues(alpha: .88)
          : Colors.white.withValues(alpha: .76),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  caution ? Icons.flag_outlined : Icons.description_outlined,
                  color: caution ? TankColors.amber : TankColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'CURRENT RECORD STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            data.state.label,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Text(
            data.wording,
            style: const TextStyle(fontSize: 17, height: 1.55),
          ),
          if (data.actionWording != null) ...[
            const Divider(height: 32),
            const Text(
              'ACCOUNTABLE RESPONSE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(data.actionWording!),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                '${data.concerns.length} open concerns',
                caution: caution,
                icon: Icons.format_list_bulleted_rounded,
              ),
              StatusPill(
                data.isCurrent ? 'Dated evidence' : 'Current evidence missing',
                caution: !data.isCurrent,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identity(BuildContext context, PublicWaterRecord data) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 136, child: WaterNetworkArtwork()),
        const SizedBox(height: 12),
        const Text(
          'The right point matters.',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Match this name to the water point where you scanned the QR.',
          style: TextStyle(color: TankColors.muted),
        ),
        const SizedBox(height: 16),
        Text(
          data.pointLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          data.facilityLabel,
          style: const TextStyle(color: TankColors.muted),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: Uri.base.toString()));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Public record link copied')),
              );
            }
          },
          icon: const Icon(Icons.link_rounded, size: 18),
          label: const Text('Copy point link'),
        ),
      ],
    ),
  );

  Widget _test(
    BuildContext context,
    PublicTest test,
    String timezone, {
    required bool historical,
  }) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              test.isSimulated
                  ? 'Simulated lab review'
                  : 'Independently reviewed',
              icon: Icons.science_outlined,
            ),
            StatusPill(
              historical ? 'Historical record' : 'Published sample',
              icon: Icons.description_outlined,
              caution: historical,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          test.indicator.label,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          test.exactFinding,
          style: const TextStyle(fontSize: 17, height: 1.55),
        ),
        const Divider(height: 40),
        LayoutBuilder(
          builder: (context, constraints) {
            final method = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'METHOD & SCOPE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: TankColors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  test.method,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reported value: ${test.value.toStringAsFixed(test.value == test.value.roundToDouble() ? 0 : 1)} ${test.units.label}',
                ),
                Text(
                  'Detection limit: ${test.detectionLimit.toStringAsFixed(1)} ${test.units.label}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Other hazards and other sampling points were not assessed by this sample.',
                  style: TextStyle(color: TankColors.muted),
                ),
              ],
            );
            final dates = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in [
                  ('Collected', test.collectedAt),
                  ('Tested', test.testedAt),
                  ('Reviewed', test.reviewedAt),
                  ('Published', test.publishedAt),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 88,
                          child: Text(
                            item.$1,
                            style: const TextStyle(color: TankColors.muted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            recordTime(item.$2, timezone: timezone),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
            return constraints.maxWidth < 640
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [method, const SizedBox(height: 24), dates],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: method),
                      const SizedBox(width: 40),
                      Expanded(child: dates),
                    ],
                  );
          },
        ),
      ],
    ),
  );
}

class RecordUnavailable extends StatelessWidget {
  const RecordUnavailable({
    super.key,
    required this.title,
    required this.message,
    this.loading = false,
    this.onRetry,
  });
  final String title;
  final String message;
  final bool loading;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => TankBackdrop(
    child: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TankBrand(surface: 'VERIFY'),
                  const SizedBox(height: 32),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Loading water record',
                      ),
                    ),
                  Text(title, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 16),
                  Text(message),
                  if (onRetry != null) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
