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
  double _navHeight = TankSpace.navHeight;
  final GlobalKey _navKey = GlobalKey();

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
    final mediaQuery = MediaQuery.of(context);
    final bottomInset =
        mediaQuery.viewPadding.bottom + mediaQuery.viewInsets.bottom;
    final effectiveNavHeight = _navHeight + bottomInset + TankSpace.screen;

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
                    padding: EdgeInsets.fromLTRB(
                      TankSpace.screen,
                      TankSpace.screen + 8,
                      TankSpace.screen,
                      effectiveNavHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TankBrand(
                                surface: 'FIELD',
                                showSimulationBadge:
                                    dashboard.facility.isSimulated,
                              ),
                            ),
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (dashboard.facility.isSimulated) ...[
                          const SimulationNotice(
                            compact: false,
                            prominent: true,
                          ),
                          const SizedBox(height: 16),
                        ],
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _screenFor(selected),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: Padding(
              key: _navKey,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: FloatingNav(
                selected: selected,
                onSelected: (value) => setState(() => selected = value),
                onHeightMeasured: (h) => setState(() => _navHeight = h),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _screenFor(int index) {
    switch (index) {
      case 0:
        return TodayScreen(
          key: const ValueKey('today'),
          onActivity: () => setState(() => selected = 3),
        );
      case 1:
        return const WaterPointsScreen(key: ValueKey('water'));
      case 2:
        return const CasesScreen(key: ValueKey('cases'));
      case 3:
        return const ActivityScreen(key: ValueKey('activity'));
      default:
        return const ProfileScreen(key: ValueKey('profile'));
    }
  }
}
