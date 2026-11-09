import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'runtime.dart';
import 'handover/handover_page.dart';

import 'field_content.dart';
import 'plain_language.dart';

class CasesScreen extends ConsumerWidget {
  const CasesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([runtime, runtime.outbox]),
      builder: (context, _) => FieldContent(
        runtime: runtime,
        header: const PageHeader(
          eyebrow: 'Cases',
          eyebrowIcon: TankMeta.fileText,
          lead: 'Concerns & ',
          emphasis: 'follow-ups.',
        ),
        empty: () => runtime.dashboard.cases.isEmpty,
        emptyState: const EmptyStateCard(
          art: LayeredRecordArt(
            accent: TankAccents.verified,
            label: 'NO OPEN CASES',
            height: 150,
          ),
          title: 'No concerns recorded',
          message:
              'This describes the record, not the quality or safety of the water.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _content(context, runtime),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, FieldRuntime runtime) => [
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TankColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How a case closes',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          const FlowSteps(steps: caseSteps),
          const SizedBox(height: 12),
          Text(
            'Repair is not resolution. A case stays open until the follow-up evidence is reviewed and the outcome is shared.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    if (runtime.dashboard.cases.isNotEmpty)
      const SectionHeading('Case records'),
    for (final item in runtime.dashboard.cases.reversed)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _CaseCard(item: item),
      ),
  ];
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.item});
  final CaseSummary item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final open = item.state != IncidentState.resolved;
    final next = Text(caseNextStep(item.state), style: textTheme.bodyMedium);
    return RecordCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LeadingRow(
            leading: AccentTile(
              sourceAccent(item.source),
              size: 48,
              background: open ? TankColors.caution : TankColors.mint,
              foreground: open ? TankColors.amber : TankColors.tealDeep,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(sourceName(item.source)),
                const SizedBox(height: 4),
                Text(item.pointLabel, style: textTheme.titleLarge),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StateChip(
                humanState(wireName(item.state)),
                tone: open ? ChipTone.caution : ChipTone.positive,
              ),
              MetaLine(TankMeta.calendar, recordDate(item.reportedAt)),
              MetaLine(
                TankMeta.user,
                item.hasOwner
                    ? 'Accountable owner assigned'
                    : 'Awaiting assignment',
                color: item.hasOwner ? null : TankColors.amber,
              ),
              if (item.dueAt != null)
                MetaLine(
                  TankMeta.clock,
                  'Response due ${recordTime(item.dueAt!)}',
                ),
            ],
          ),
          const SizedBox(height: 16),
          FlowSteps(steps: caseSteps, current: caseStep(item.state)),
          const SizedBox(height: 16),
          if (caseNeedsAction(item))
            ExceptionPanel(
              label: 'What happens next',
              title: 'An owner is needed',
              message: caseNextStep(item.state),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TankColors.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('What happens next'),
                  const SizedBox(height: 4),
                  next,
                ],
              ),
            ),
          const SizedBox(height: 12),
          PrepareHandoverButton(
            kind: 'incident',
            id: item.id,
            label: item.pointLabel,
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: Text(
                'Case history (${item.events.length})',
                style: textTheme.titleSmall,
              ),
              children: [
                for (final event in item.events)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 7, right: 12),
                          decoration: const BoxDecoration(
                            color: TankColors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(child: Text(event)),
                      ],
                    ),
                  ),
                if (item.events.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No updates have been recorded on this case yet.',
                      style: textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
