import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';

enum ManagerViewState { loading, empty, error, denied, offline, stale, success }

class ManagerStatePanel extends StatelessWidget {
  const ManagerStatePanel({
    super.key,
    required this.state,
    this.child,
    this.onRetry,
  });
  final ManagerViewState state;
  final Widget? child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => switch (state) {
    ManagerViewState.loading => const ManagerStateSkeleton(),
    ManagerViewState.empty => const NoticeCard(
      title: 'Nothing in scope',
      message: 'Authoritative records will appear here when available.',
    ),
    ManagerViewState.error => NoticeCard(
      title: 'Manager view unavailable',
      message: 'The service could not load this screen.',
      action: TextButton(onPressed: onRetry, child: const Text('Retry')),
    ),
    ManagerViewState.denied => const NoticeCard(
      title: 'Permission required',
      message: 'Your scoped membership does not allow this manager view.',
      icon: Icons.lock_outline,
    ),
    ManagerViewState.offline => const NoticeCard(
      title: 'Offline',
      message:
          'Showing the last known record. Authoritative actions are paused.',
      icon: Icons.cloud_off_outlined,
    ),
    ManagerViewState.stale => const NoticeCard(
      title: 'Stale data',
      message:
          'Compare the as-of time before using this record for a decision.',
      icon: Icons.schedule,
      caution: true,
    ),
    ManagerViewState.success => child ?? const SizedBox.shrink(),
  };
}

class ManagerStateSkeleton extends StatelessWidget {
  const ManagerStateSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      FrostedSkeletonCard(lines: 2),
      SizedBox(height: 12),
      FrostedSkeletonCard(lines: 2),
    ],
  );
}
