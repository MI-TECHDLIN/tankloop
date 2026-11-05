import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'manager_controller.dart';
import 'manager_screen_states.dart';
import 'manager_widgets.dart';

class ManagerFacilitiesScreen extends StatefulWidget {
  const ManagerFacilitiesScreen({super.key, required this.controller});
  final ManagerController controller;
  @override
  State<ManagerFacilitiesScreen> createState() =>
      _ManagerFacilitiesScreenState();
}

class _ManagerFacilitiesScreenState extends State<ManagerFacilitiesScreen> {
  final search = TextEditingController();
  AssetType? type;
  bool showRetired = false;
  String? selectedId;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void clear() => setState(() {
    search.clear();
    type = null;
    showRetired = false;
    selectedId = null;
  });

  @override
  Widget build(BuildContext context) => ManagerScreenFrame(
    title: 'Facilities',
    controller: widget.controller,
    isEmpty: (data) => data.assets.isEmpty,
    emptyMessage: 'This facility has no registered assets yet.',
    builder: (context, data) {
      final query = search.text.trim().toLowerCase();
      final assets = data.assets
          .where(
            (a) =>
                (showRetired || a.retiredAt == null) &&
                (type == null || a.type == type) &&
                '${a.label} ${a.id}'.toLowerCase().contains(query),
          )
          .toList();
      final selected = assets.where((a) => a.id == selectedId).firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${data.systems.length} water network(s) · ${data.points.length} sampling points · ${data.assets.where((a) => a.retiredAt == null).length} active assets',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search assets',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All types'),
                selected: type == null,
                onSelected: (_) => setState(() => type = null),
              ),
              for (final value in AssetType.values)
                FilterChip(
                  label: Text(humanState(value.name)),
                  selected: type == value,
                  onSelected: (_) => setState(() => type = value),
                ),
              FilterChip(
                label: const Text('Include retired'),
                selected: showRetired,
                onSelected: (value) => setState(() => showRetired = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (assets.isEmpty)
            ManagerNoMatches(onClear: clear)
          else
            ManagerRecordLayout(
              onClose: () => setState(() => selectedId = null),
              list: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final asset in assets)
                    ManagerRecordTile(
                      key: ValueKey('asset-${asset.id}'),
                      title: asset.label,
                      subtitle:
                          '${humanState(asset.type.name)} · ${data.systems.where((s) => s.id == asset.systemId).firstOrNull?.label ?? 'Network link unavailable'}',
                      selected: selected?.id == asset.id,
                      onOpen: () => setState(() => selectedId = asset.id),
                      badges: [
                        StatusPill(
                          asset.retiredAt == null
                              ? 'Active asset'
                              : 'Retired asset',
                          caution: asset.retiredAt != null,
                        ),
                        StatusPill(
                          '${data.inspections.where((i) => i.task.assetId == asset.id && i.overdue(data.asOf)).length} overdue inspections',
                          icon: Icons.schedule,
                        ),
                      ],
                    ),
                ],
              ),
              detail: selected == null ? null : _detail(data, selected),
            ),
        ],
      );
    },
  );

  Widget _detail(ManagerWorkspace data, Asset asset) {
    final points = data.points.where((p) => p.assetId == asset.id).toList();
    final children = data.assets.where((a) => a.parentId == asset.id).toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(asset.label, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          ManagerDetail('Asset ID', asset.id),
          ManagerDetail('Facility', data.facility.label),
          ManagerDetail('Time zone', data.facility.timezone),
          ManagerDetail('Asset type', humanState(asset.type.name)),
          ManagerDetail(
            'Upstream asset',
            asset.parentId == null
                ? 'Network origin'
                : data.asset(asset.parentId!)?.label ?? 'Unknown upstream link',
          ),
          if (asset.capacityLitres != null)
            ManagerDetail('Capacity', '${asset.capacityLitres} litres'),
          if (asset.retiredAt != null)
            ManagerDetail(
              'Retired',
              recordTime(asset.retiredAt!, timezone: data.facility.timezone),
            ),
          if (children.isNotEmpty) ...[
            const Text(
              'Downstream assets',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final child in children)
              TextButton.icon(
                onPressed: () => setState(() {
                  selectedId = child.id;
                  type = null;
                  search.clear();
                  showRetired = child.retiredAt != null;
                }),
                icon: const Icon(Icons.subdirectory_arrow_right),
                label: Text(child.label),
              ),
          ],
          const SectionHeading('Sampling points and QR identities'),
          if (points.isEmpty)
            const Text('No sampling points are registered on this asset.'),
          for (final point in points) ...[
            Text(point.label, style: Theme.of(context).textTheme.titleMedium),
            ManagerDetail('Point ID', point.id),
            Text(
              '${data.samples.where((s) => s.sample.pointId == point.id).length} recorded samples',
            ),
            if (!data.qrs.any((q) => q.pointId == point.id))
              const Text('No QR identity issued.'),
            for (final qr in data.qrs.where((q) => q.pointId == point.id)) ...[
              const SizedBox(height: 12),
              StatusPill(
                qr.revokedAt == null
                    ? 'Active QR identity'
                    : 'Revoked QR identity',
                caution: qr.revokedAt != null,
                icon: Icons.qr_code_2,
              ),
              const SizedBox(height: 12),
              ManagerDetail('Opaque point code', qr.token),
              ManagerDetail(
                'Issued',
                recordTime(qr.issuedAt, timezone: data.facility.timezone),
              ),
              if (qr.revokedAt != null)
                ManagerDetail(
                  'Revoked',
                  recordTime(qr.revokedAt!, timezone: data.facility.timezone),
                ),
              if (qr.revokedAt == null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.base.replace(
                          fragment: '/point/${qr.token}',
                        );
                        await Clipboard.setData(
                          ClipboardData(text: uri.toString()),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Public point link copied.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy public link'),
                    ),
                    OutlinedButton(
                      onPressed: !widget.controller.canWrite
                          ? null
                          : () async {
                              final reason = await managerReason(
                                context,
                                title: 'Revoke QR identity',
                                message:
                                    'This permanently disables this printed point code. It cannot be reattached or reactivated. The original identity and audit trail are retained.',
                                action: 'Revoke QR',
                              );
                              if (reason == null) return;
                              await widget.controller.act(
                                () => widget.controller.repository.revokeQr(
                                  token: qr.token,
                                  reason: reason,
                                ),
                                'QR identity revoked.',
                                basedOn: data,
                              );
                            },
                      child: const Text('Revoke QR'),
                    ),
                  ],
                ),
              ManagerAuditTrail(
                events: data.auditFor(qr.token),
                timezone: data.facility.timezone,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
