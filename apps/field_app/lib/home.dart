import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'runtime.dart';
import 'today.dart';
import 'water_points.dart';
import 'cases.dart';
import 'activity.dart';
import 'profile.dart';

class FieldHome extends ConsumerStatefulWidget {
  const FieldHome({super.key});
  @override
  ConsumerState<FieldHome> createState() => _FieldHomeState();
}

class _FieldHomeState extends ConsumerState<FieldHome> {
  int selected = 0;
  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The action could not finish. Your saved records are retained.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([
        runtime,
        runtime.outbox,
        runtime.workOutbox,
      ]),
      builder: (context, _) {
        final dashboard = runtime.dashboard;
        return TankBackdrop(
          child: Scaffold(
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 144),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: TankBrand()),
                            IconButton.filledTonal(
                              tooltip: 'Refresh assignments',
                              onPressed: runtime.refreshing
                                  ? null
                                  : () => _perform(runtime.refresh),
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Scan water point QR',
                              onPressed: () => context.push('/scan'),
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Profile and exercise controls',
                              onPressed: () => setState(() => selected = 4),
                              icon: const Icon(Icons.person_outline_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (dashboard.facility.isSimulated) ...[
                          const SimulationNotice(compact: true),
                          const SizedBox(height: 20),
                        ],
                        switch (selected) {
                          0 => TodayScreen(
                            onActivity: () => setState(() => selected = 3),
                          ),
                          1 => const WaterPointsScreen(),
                          2 => const CasesScreen(),
                          3 => const ActivityScreen(),
                          _ => const ProfileScreen(),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: FloatingNav(
              selected: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        );
      },
    );
  }
}
