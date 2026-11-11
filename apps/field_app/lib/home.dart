import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // The bar's measured height already includes its safe-area inset.
    final effectiveNavHeight = _navHeight + TankSpace.screen;

    return AnimatedBuilder(
      animation: Listenable.merge([
        runtime,
        runtime.outbox,
        runtime.workOutbox,
      ]),
      builder: (context, _) {
        return TankBackdrop(
          child: Scaffold(
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: SizedBox.expand(
                    child: RefreshIndicator(
                      onRefresh: () => _perform(runtime.refresh),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          TankSpace.screen,
                          TankSpace.screen + 8,
                          TankSpace.screen,
                          effectiveNavHeight,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _screenFor(selected),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Fade scrolled content out behind the floating bar so text
            // never competes with the navigation labels.
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    TankColors.canvas.withValues(alpha: 0),
                    TankColors.canvas.withValues(alpha: .94),
                  ],
                  stops: const [0, .5],
                ),
              ),
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
