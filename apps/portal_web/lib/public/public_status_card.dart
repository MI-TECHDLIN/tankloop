import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'public_surface.dart';

class PublicStatusCard extends StatelessWidget {
  const PublicStatusCard({
    super.key,
    required this.record,
    required this.textFirst,
    required this.isSnapshot,
  });
  final PublicWaterRecord record;
  final bool textFirst;
  final bool isSnapshot;

  @override
  Widget build(BuildContext context) {
    final caution = record.concerns.isNotEmpty || !record.isCurrent;
    return PublicSurface(
      textFirst: textFirst,
      caution: caution,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  caution ? Icons.flag_outlined : Icons.description_outlined,
                  color: caution ? TankColors.amber : TankColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isSnapshot
                      ? 'LAST LOADED RECORD STATUS'
                      : 'CURRENT RECORD STATUS',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              record.state.label,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            record.wording,
            style: const TextStyle(fontSize: 17, height: 1.5),
          ),
          if (record.actionWording != null) ...[
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
            Text(record.actionWording!),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                '${record.concerns.length} open concerns',
                icon: Icons.format_list_bulleted_rounded,
                caution: record.concerns.isNotEmpty,
              ),
              StatusPill(
                isSnapshot
                    ? 'Refresh needed'
                    : record.isCurrent
                    ? 'Dated sample record'
                    : 'Current evidence missing',
                icon: Icons.schedule_rounded,
                caution: isSnapshot || !record.isCurrent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
