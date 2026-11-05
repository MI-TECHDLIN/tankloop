import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';

class ManagerCatalogScreen extends StatelessWidget {
  const ManagerCatalogScreen({
    super.key,
    required this.title,
    required this.snapshot,
    required this.kind,
  });
  final String title;
  final DashboardSnapshot snapshot;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final rows = switch (kind) {
      'facilities' => [
        '${snapshot.facility.label} · ${snapshot.facility.timezone}',
        '${snapshot.points.length} sampling points',
        '${snapshot.assets.length} active assets',
      ],
      'inspections' =>
        snapshot.inspections
            .map(
              (task) =>
                  '${task.id.substring(0, 8)} · due ${task.dueAt.toIso8601String().substring(0, 10)}',
            )
            .toList(),
      'samples' =>
        snapshot.points
            .map((point) => '${point.label} · evidence status requires review')
            .toList(),
      'team' => [
        'Scoped manager · facility access',
        'Field responders · assigned work',
        'Laboratory reviewers · independent evidence',
      ],
      _ => <String>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title),
        if (rows.isEmpty)
          const NoticeCard(
            title: 'Nothing in scope',
            message: 'Authoritative records will appear here when available.',
          )
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.chevron_right, color: TankColors.teal),
                    const SizedBox(width: 12),
                    Expanded(child: Text(row)),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const StatusPill(
          'Freshness and permissions are checked by the data service',
          icon: Icons.verified_user_outlined,
          compact: true,
        ),
      ],
    );
  }
}
