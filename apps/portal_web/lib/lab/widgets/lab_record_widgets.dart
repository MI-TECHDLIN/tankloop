import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';

String labStage(LabRecord record) => switch (record.state) {
  ResultState.collected => 'Awaiting receipt',
  ResultState.received => 'Intake pending',
  ResultState.valid => 'Accepted for testing',
  ResultState.rejected => 'Sample rejected',
  ResultState.tested => 'Awaiting review',
  ResultState.reviewed || ResultState.published =>
    !record.isReviewed
        ? 'Review evidence incomplete'
        : record.sample.isSimulated
        ? 'Simulated lab review'
        : 'Independently reviewed',
  ResultState.superseded => 'Superseded result',
};

String labNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

class LabStagePill extends StatelessWidget {
  const LabStagePill(this.record, {super.key});
  final LabRecord record;
  @override
  Widget build(BuildContext context) => StatusPill(
    labStage(record),
    caution: record.state == ResultState.rejected || record.isHistorical,
    icon: record.state == ResultState.rejected
        ? Icons.block_outlined
        : record.isHistorical
        ? Icons.history_rounded
        : record.isReviewed
        ? Icons.fact_check_outlined
        : Icons.pending_actions_outlined,
  );
}

class LabRecordPicker extends StatelessWidget {
  const LabRecordPicker({
    super.key,
    required this.records,
    required this.selected,
    required this.onSelected,
  });
  final List<LabRecord> records;
  final LabRecord selected;
  final ValueChanged<LabRecord> onSelected;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey(selected.id),
    initialValue: selected.id,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Sample record'),
    items: records
        .map(
          (r) => DropdownMenuItem(
            value: r.id,
            child: Text(
              '${r.sample.code} · ${r.pointLabel}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(),
    onChanged: (id) {
      if (id != null) onSelected(records.singleWhere((r) => r.id == id));
    },
  );
}

class LabRecordTile extends StatelessWidget {
  const LabRecordTile({
    super.key,
    required this.record,
    required this.timezone,
    required this.onOpen,
  });
  final LabRecord record;
  final String timezone;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.sample.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(record.pointLabel),
                const SizedBox(height: 4),
                Text(
                  'Collected ${recordTime(record.sample.collectedAt, timezone: timezone)}',
                  style: const TextStyle(fontSize: 12, color: TankColors.muted),
                ),
              ],
            );
            final status = LabStagePill(record);
            return constraints.maxWidth < 600
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [identity, const SizedBox(height: 12), status],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TankColors.mint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.science_outlined,
                          color: TankColors.teal,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: identity),
                      const SizedBox(width: 16),
                      Flexible(child: status),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  );
          },
        ),
      ),
    ),
  );
}

class LabSampleIdentity extends StatelessWidget {
  const LabSampleIdentity({
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.sample.code,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(record.pointLabel),
              ],
            ),
            LabStagePill(record),
          ],
        ),
        const Divider(height: 32),
        LabDetail('Sample ID', record.sample.id),
        LabDetail(
          'Collected',
          recordTime(record.sample.collectedAt, timezone: timezone),
        ),
        LabDetail('Collector', record.sample.collectorId),
        LabDetail('Planned method', record.sample.intendedMethod),
        LabDetail('Preservation / transport', record.preservationNote),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              'Source: ${humanState(wireName(record.source))}',
              icon: Icons.biotech_outlined,
            ),
            StatusPill(
              '${record.openIncidentCount} open incidents at this point',
              caution: record.openIncidentCount > 0,
              icon: Icons.flag_outlined,
            ),
          ],
        ),
        if (record.state == ResultState.rejected) ...[
          const SizedBox(height: 16),
          const Text(
            'No valid result from this sample.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            record.rejectionReason ?? 'Review the recorded intake decision.',
          ),
        ],
      ],
    ),
  );
}

class LabDetail extends StatelessWidget {
  const LabDetail(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final caption = Text(
          label,
          style: const TextStyle(color: TankColors.muted, fontSize: 13),
        );
        final detail = SelectableText(
          value,
          style: const TextStyle(fontSize: 14),
        );
        return constraints.maxWidth < 480
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [caption, const SizedBox(height: 4), detail],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 168, child: caption),
                  Expanded(child: detail),
                ],
              );
      },
    ),
  );
}

class LabColumns extends StatelessWidget {
  const LabColumns({super.key, required this.primary, required this.secondary});
  final Widget primary;
  final Widget secondary;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 960
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, const SizedBox(height: 20), secondary],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: primary),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: secondary),
            ],
          ),
  );
}
