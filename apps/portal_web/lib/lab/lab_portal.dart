import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_localization/localization.dart';
import 'lab_controller.dart';
import 'lab_navigation.dart';
import 'screens/inbox_screen.dart';
import 'screens/results_screen.dart';
import 'screens/revisions_screen.dart';
import 'screens/sample_intake_screen.dart';
import 'widgets/lab_access_panel.dart';

class LabPortal extends StatefulWidget {
  const LabPortal({
    super.key,
    required this.repository,
    required this.section,
    required this.onNavigate,
    this.recordId,
    this.authClient,
  });
  final LabRepository repository;
  final LabSection section;
  final String? recordId;
  final LabNavigate onNavigate;
  final SupabaseClient? authClient;
  @override
  State<LabPortal> createState() => _LabPortalState();
}

class _LabPortalState extends State<LabPortal> {
  final scaffold = GlobalKey<ScaffoldState>();
  late final controller = LabController(widget.repository);
  StreamSubscription<AuthState>? authSubscription;
  String? userId;
  @override
  void initState() {
    super.initState();
    userId = widget.authClient?.auth.currentUser?.id;
    authSubscription = widget.authClient?.auth.onAuthStateChange.listen((
      event,
    ) {
      final nextId = event.session?.user.id;
      if (nextId == userId) return;
      userId = nextId;
      controller.sessionChanged();
      if (nextId != null) unawaited(controller.refresh());
    });
    unawaited(controller.refresh());
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TankBackdrop(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 880;
        return Scaffold(
          key: scaffold,
          drawer: wide ? null : Drawer(child: SafeArea(child: _navigation())),
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wide)
                  SizedBox(
                    width: 240,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _navigation(),
                    ),
                  ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 12 : 16,
                        24,
                        wide ? 32 : 16,
                        40,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!wide) ...[
                                Row(
                                  children: [
                                    const Expanded(
                                      child: TankBrand(surface: 'LAB'),
                                    ),
                                    Builder(
                                      builder: (context) => IconButton(
                                        tooltip: 'Open lab navigation',
                                        onPressed: () =>
                                            Scaffold.of(context).openDrawer(),
                                        icon: const Icon(Icons.menu_rounded),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                              _toolbar(),
                              const SizedBox(height: 28),
                              KeyedSubtree(
                                key: ValueKey(
                                  '${controller.workspace?.actorId}:${controller.workspace?.facility.id}',
                                ),
                                child: _screen(),
                              ),
                              if (controller.phase ==
                                      LabPhase.permissionDenied &&
                                  widget.authClient != null) ...[
                                const SizedBox(height: 20),
                                if (widget.authClient!.auth.currentUser == null)
                                  LabAccessPanel(
                                    client: widget.authClient!,
                                    onSignedIn: () => controller.refresh(),
                                  )
                                else
                                  const NoticeCard(
                                    title: 'This account has no lab assignment',
                                    message:
                                        'Ask the organization administrator for an active laboratory reviewer membership. Refresh after it has been assigned, or sign out to use a different account.',
                                  ),
                              ],
                              if (controller.workspace case final data?) ...[
                                const SizedBox(height: 28),
                                Text(
                                  '${data.facility.isSimulated ? 'Simulated record clock' : 'Record as of'}: ${recordTime(data.asOf, timezone: data.facility.timezone)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: TankColors.muted,
                                  ),
                                ),
                                if (data.facility.isSimulated)
                                  Text(
                                    'Model ${data.modelVersion ?? 1} · Seed ${data.simulationSeed ?? 'unrecorded'} · Generated workflow, not measured water quality',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: TankColors.muted,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _navigation() => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: TankBrand(surface: 'LAB'),
        ),
        const SizedBox(height: 36),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'LABORATORY',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
              color: TankColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final section in LabSection.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              selected: widget.section == section,
              child: ListTile(
                selected: widget.section == section,
                selectedTileColor: TankColors.navy,
                selectedColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                leading: Icon(section.icon, size: 22),
                title: Text(
                  section.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  scaffold.currentState?.closeDrawer();
                  widget.onNavigate(section, null);
                },
              ),
            ),
          ),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Evidence stays dated.\nReview stays accountable.',
            style: TextStyle(
              color: TankColors.muted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _toolbar() {
    final data = controller.workspace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            StatusPill(
              widget.repository.serverBacked
                  ? 'Connected lab workspace'
                  : 'Standalone simulation playback',
              icon: widget.repository.serverBacked
                  ? Icons.cloud_outlined
                  : Icons.science_outlined,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Refresh laboratory workspace',
                  onPressed: controller.busy || controller.refreshing
                      ? null
                      : () => controller.refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                if (widget.repository
                    case final SimulationLabRepository simulation) ...[
                  OutlinedButton.icon(
                    onPressed:
                        controller.busy ||
                            controller.refreshing ||
                            controller.offlineExercise
                        ? null
                        : () {
                            simulation.engine.advance(const Duration(hours: 1));
                            controller.refresh();
                          },
                    icon: const Icon(Icons.fast_forward_outlined, size: 18),
                    label: const Text('Advance 1 hour'),
                  ),
                  IconButton(
                    tooltip: controller.offlineExercise
                        ? 'End offline exercise'
                        : 'Start offline exercise',
                    onPressed: () => controller.setOfflineExercise(
                      !controller.offlineExercise,
                    ),
                    icon: Icon(
                      controller.offlineExercise
                          ? Icons.cloud_off_outlined
                          : Icons.wifi_off_outlined,
                    ),
                  ),
                ],
                if (widget.authClient?.auth.currentUser != null)
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            try {
                              await widget.authClient!.auth.signOut();
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sign-out could not be completed. Reconnect and retry.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    child: const Text('Sign out'),
                  ),
              ],
            ),
          ],
        ),
        if (data != null) ...[
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: ValueKey(data.facility.id),
            initialValue: data.facility.id,
            decoration: const InputDecoration(labelText: 'Assigned facility'),
            isExpanded: true,
            items: data.facilities
                .map(
                  (f) => DropdownMenuItem(
                    value: f.id,
                    child: Text(f.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: controller.busy || controller.refreshing
                ? null
                : (id) {
                    if (id != null) {
                      controller.refresh(facilityId: id);
                      widget.onNavigate(widget.section, null);
                    }
                  },
          ),
        ],
      ],
    );
  }

  Widget _screen() => switch (widget.section) {
    LabSection.inbox => LabInboxScreen(
      controller: controller,
      onNavigate: widget.onNavigate,
    ),
    LabSection.intake => LabSampleIntakeScreen(
      controller: controller,
      onNavigate: widget.onNavigate,
      recordId: widget.recordId,
    ),
    LabSection.results => LabResultsScreen(
      controller: controller,
      onNavigate: widget.onNavigate,
      recordId: widget.recordId,
    ),
    LabSection.revisions => LabRevisionsScreen(
      controller: controller,
      onNavigate: widget.onNavigate,
      recordId: widget.recordId,
    ),
  };
}
