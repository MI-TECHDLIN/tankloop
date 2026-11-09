import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_localization/localization.dart';
import 'loading.dart';
import 'runtime.dart';

/// Screen state follows real runtime events. Offline/stale content stays usable;
/// revoked membership hides cached facility details and disables mutations.
///
/// Order on screen: [header], then connection notices, then the empty state
/// when [empty] holds, then [child].
class FieldContent extends StatelessWidget {
  const FieldContent({
    super.key,
    required this.runtime,
    required this.empty,
    required this.child,
    this.header,
    this.emptyState,
    this.loading = false,
    this.error,
    this.onRetry,
  });
  final FieldRuntime runtime;
  final bool Function() empty;
  final Widget child;
  final Widget? header;
  final Widget? emptyState;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([runtime, runtime.outbox, runtime.workOutbox]),
    builder: (context, _) {
      if (runtime.accessRevoked) {
        return const NoticeCard(
          key: ValueKey('permission-denied'),
          title: 'Facility access is restricted',
          message:
              'Ask your manager to renew access. Local drafts are retained for this account.',
          icon: Symbols.lock_rounded,
          caution: true,
        );
      }
      if (loading) return const FieldLoadingSkeleton();
      final failure = error ?? runtime.error;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 20)],
          if (failure != null) ...[
            NoticeCard(
              key: const ValueKey('error'),
              title: 'Could not finish',
              message: failure,
              icon: Symbols.error_rounded,
              caution: true,
              action: TextButton.icon(
                onPressed: onRetry ?? runtime.refresh,
                icon: const Icon(Symbols.refresh_rounded, size: 20),
                label: const Text('Retry'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!runtime.online) ...[
            const NoticeCard(
              key: ValueKey('offline'),
              title: 'Offline - saved on this device',
              message:
                  'Keep working with downloaded assignments. Queued work uploads when connected.',
              icon: Symbols.cloud_off_rounded,
              caution: true,
            ),
            const SizedBox(height: 16),
          ] else if (runtime.stale) ...[
            NoticeCard(
              key: const ValueKey('stale'),
              title: 'Previously loaded assignments',
              message:
                  'Last loaded ${recordTime(runtime.dashboard.asOf)}. Refresh for current assignments.',
              icon: Symbols.history_rounded,
              caution: true,
            ),
            const SizedBox(height: 16),
          ],
          if (empty()) ...[
            KeyedSubtree(
              key: const ValueKey('empty'),
              child:
                  emptyState ??
                  EmptyStateCard(
                    title: 'Nothing to show yet',
                    message:
                        'Refresh when connected to check for assigned records. This is not a water-quality finding.',
                    actions: [
                      OutlinedButton.icon(
                        onPressed: runtime.refresh,
                        icon: const Icon(Symbols.refresh_rounded),
                        label: const Text('Refresh assignments'),
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: 16),
          ],
          KeyedSubtree(key: const ValueKey('success'), child: child),
        ],
      );
    },
  );
}
