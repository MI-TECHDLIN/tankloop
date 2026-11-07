import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'runtime.dart';

import 'field_content.dart';

class CasesScreen extends ConsumerWidget {
  const CasesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([runtime, runtime.outbox]),
      builder: (context, _) => FieldContent(
        runtime: runtime,
        empty: () => runtime.dashboard.cases.isEmpty,
        child: Builder(
          builder: (context) => RefreshIndicator(
            onRefresh: () => runtime.refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(TankSpace.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _content(context, runtime),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, FieldRuntime runtime) => [
    Text(
      'Every concern.\nAn accountable next step.',
      style: Theme.of(context).textTheme.displayMedium,
    ),
    const SizedBox(height: 16),
    NoticeCard(
      prominent: true,
      title: 'Repair is not resolution',
      message:
          'Cases remain open until the applicable follow-up evidence is reviewed and communication is recorded.',
      icon: Icons.fact_check_outlined,
    ),
    const SectionHeading('Case records'),
    if (runtime.dashboard.cases.isEmpty)
      const NoticeCard(
        title: 'No concerns recorded',
        message:
            'This describes the record, not the quality or safety of the water.',
      ),
    for (final item in runtime.dashboard.cases.reversed)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text(
              item.pointLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${humanState(wireName(item.state))}\n${humanState(wireName(item.source))} · ${recordDate(item.reportedAt)}',
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(
                  item.hasOwner
                      ? 'Accountable owner assigned'
                      : 'Awaiting assignment',
                  icon: Icons.person_outline_rounded,
                  caution: !item.hasOwner,
                ),
              ),
              const SizedBox(height: 12),
              if (item.dueAt != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Response due ${recordTime(item.dueAt!)}',
                    style: const TextStyle(color: TankColors.muted),
                  ),
                ),
              for (final event in item.events)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: TankColors.teal),
                      const SizedBox(width: 12),
                      Expanded(child: Text(event)),
                    ],
                  ),
                ),
              if (item.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Privileged transitions and audit are available through the server RPCs.',
                    style: TextStyle(color: TankColors.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
  ];
}
