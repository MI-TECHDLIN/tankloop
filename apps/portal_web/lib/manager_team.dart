import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'manager_controller.dart';
import 'manager_screen_states.dart';
import 'manager_widgets.dart';

class ManagerTeamScreen extends StatefulWidget {
  const ManagerTeamScreen({super.key, required this.controller});
  final ManagerController controller;
  @override
  State<ManagerTeamScreen> createState() => _ManagerTeamScreenState();
}

class _ManagerTeamScreenState extends State<ManagerTeamScreen> {
  final search = TextEditingController();
  Role? role;
  bool activeOnly = false;
  String? selectedId;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void clear() => setState(() {
    search.clear();
    role = null;
    activeOnly = false;
    selectedId = null;
  });
  String status(ManagerMembership member, ManagerWorkspace data) =>
      member.revoked
      ? 'Revoked'
      : member.activeAt(data.fetchedAt)
      ? 'Active membership'
      : 'Expired';

  @override
  Widget build(BuildContext context) => ManagerScreenFrame(
    title: 'Team',
    controller: widget.controller,
    isEmpty: (data) => data.members.isEmpty,
    emptyMessage: 'No membership records are available in this facility scope.',
    builder: (context, data) {
      final query = search.text.trim().toLowerCase();
      final members = data.members
          .where(
            (m) =>
                '${m.userId} ${m.role.name}'.toLowerCase().contains(query) &&
                (role == null || m.role == role) &&
                (!activeOnly || m.activeAt(data.fetchedAt)),
          )
          .toList();
      final selected = members.where((m) => m.id == selectedId).firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NoticeCard(
            title: 'Membership authority',
            message:
                'Invites, revocations and role changes are provisioned by the organization administrator. Review scoped memberships and accountable work below.',
            icon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search member IDs or roles',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All roles'),
                selected: role == null,
                onSelected: (_) => setState(() => role = null),
              ),
              for (final value in Role.values)
                FilterChip(
                  label: Text(humanState(value.name)),
                  selected: role == value,
                  onSelected: (_) => setState(() => role = value),
                ),
              FilterChip(
                label: const Text('Active only'),
                selected: activeOnly,
                onSelected: (value) => setState(() => activeOnly = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (members.isEmpty)
            ManagerNoMatches(onClear: clear)
          else
            ManagerRecordLayout(
              onClose: () => setState(() => selectedId = null),
              list: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final member in members)
                    ManagerRecordTile(
                      key: ValueKey('member-${member.id}'),
                      title:
                          '${humanState(member.role.name)} · ${member.userId.substring(0, 8)}',
                      subtitle: member.facilityId == null
                          ? 'Organization-wide access'
                          : data.facility.label,
                      selected: selected?.id == member.id,
                      onOpen: () => setState(() => selectedId = member.id),
                      badges: [
                        StatusPill(
                          status(member, data),
                          caution: !member.activeAt(data.fetchedAt),
                        ),
                        if (member.userId == data.actorId)
                          const StatusPill('Current actor'),
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

  Widget _detail(ManagerWorkspace data, ManagerMembership member) {
    final inspections = data.inspections
        .where((i) => i.assignedTo == member.userId && !i.task.isSubmitted)
        .toList();
    final incidents = data.incidents
        .where((i) => i.ownerId == member.userId && i.isOpen)
        .toList();
    final orders = data.orders
        .where(
          (w) =>
              w.assigneeId == member.userId &&
              w.state != WorkOrderState.accepted,
        )
        .toList();
    final events = data.audit.where((a) => a.actorId == member.userId).toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Membership detail',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          StatusPill(
            status(member, data),
            caution: !member.activeAt(data.fetchedAt),
          ),
          const SizedBox(height: 16),
          ManagerDetail('Member ID', member.userId),
          ManagerDetail('Membership ID', member.id),
          ManagerDetail('Role', humanState(member.role.name)),
          ManagerDetail(
            'Access scope',
            member.facilityId == null
                ? 'All facilities in this organization'
                : data.facility.label,
          ),
          ManagerDetail(
            'Valid until',
            member.validUntil == null
                ? 'No expiry recorded'
                : recordTime(
                    member.validUntil!,
                    timezone: data.facility.timezone,
                  ),
          ),
          const Text(
            'Membership expiry is evaluated against the actual service clock, separately from the exercise clock.',
          ),
          const SectionHeading('Assigned inspections'),
          if (inspections.isEmpty)
            const Text('No outstanding inspections assigned.'),
          for (final item in inspections)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${data.asset(item.task.assetId)?.label ?? item.task.assetId} · due ${recordTime(item.task.dueAt, timezone: data.facility.timezone)}${item.overdue(data.asOf) ? ' · Overdue' : ''}',
              ),
            ),
          if (incidents.isNotEmpty)
            ManagerIncidentList(
              incidents: incidents,
              controller: widget.controller,
              data: data,
            ),
          const SectionHeading('Assigned work'),
          ManagerWorkOrderList(
            orders: orders,
            controller: widget.controller,
            data: data,
          ),
          ManagerAuditTrail(events: events, timezone: data.facility.timezone),
        ],
      ),
    );
  }
}
