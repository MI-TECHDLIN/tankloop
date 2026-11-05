import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_localization/localization.dart';
import 'manager_controller.dart';

export 'manager_controller.dart' show ManagerViewState;

class ManagerScreenFrame extends StatelessWidget {
  const ManagerScreenFrame({
    super.key,
    required this.title,
    required this.controller,
    required this.isEmpty,
    required this.builder,
    this.emptyMessage = 'Records will appear here when available.',
  });
  final String title;
  final ManagerController controller;
  final bool Function(ManagerWorkspace) isEmpty;
  final Widget Function(BuildContext, ManagerWorkspace) builder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final data = controller.workspace;
      final phase =
          controller.phase == ManagerViewState.success &&
              data != null &&
              isEmpty(data)
          ? ManagerViewState.empty
          : controller.phase;
      final showRecords =
          data != null &&
          {
            ManagerViewState.success,
            ManagerViewState.offline,
            ManagerViewState.stale,
          }.contains(phase);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(
            title,
            trailing: IconButton(
              tooltip: 'Refresh $title',
              onPressed: controller.refreshing || controller.busy
                  ? null
                  : () => controller.refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (data != null) ...[
            if (data.facility.isSimulated)
              const SimulationNotice(compact: true),
            const SizedBox(height: 12),
            Text(
              '${data.facility.isSimulated ? 'Exercise clock' : 'Records as of'}: ${recordTime(data.asOf, timezone: data.facility.timezone)}',
              style: const TextStyle(color: TankColors.muted, fontSize: 13),
            ),
            Text(
              'Last fetched: ${recordTime(data.fetchedAt, timezone: data.facility.timezone)}',
              style: const TextStyle(color: TankColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
          ],
          if (controller.refreshing && data != null) ...[
            Semantics(
              label: 'Refreshing manager records',
              child: const FrostedSkeleton(height: 8),
            ),
            const SizedBox(height: 12),
          ],
          if (controller.actionMessage != null) ...[
            NoticeCard(
              title: 'Action status',
              message: controller.actionMessage!,
            ),
            const SizedBox(height: 12),
          ],
          ManagerStatePanel(
            state: phase,
            onRetry: () => controller.offlineExercise
                ? controller.setOfflineExercise(false)
                : controller.refresh(),
            emptyMessage: emptyMessage,
            message: controller.message,
            child: showRecords ? builder(context, data) : null,
          ),
        ],
      );
    },
  );
}

class ManagerStatePanel extends StatelessWidget {
  const ManagerStatePanel({
    super.key,
    required this.state,
    this.child,
    this.onRetry,
    this.emptyMessage =
        'Authoritative records will appear here when available.',
    this.message,
  });
  final ManagerViewState state;
  final Widget? child;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final String? message;

  @override
  Widget build(BuildContext context) => switch (state) {
    ManagerViewState.loading => const ManagerStateSkeleton(),
    ManagerViewState.empty => NoticeCard(
      title: 'Nothing in scope',
      message: emptyMessage,
    ),
    ManagerViewState.error => NoticeCard(
      title: 'Manager view unavailable',
      message: message ?? 'The service could not load this screen.',
      action: TextButton(onPressed: onRetry, child: const Text('Retry')),
    ),
    ManagerViewState.denied => NoticeCard(
      title: 'Permission required',
      message:
          message ?? 'Your scoped membership does not allow this manager view.',
      icon: Icons.lock_outline,
    ),
    ManagerViewState.offline || ManagerViewState.stale => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoticeCard(
          title: state == ManagerViewState.offline ? 'Offline' : 'Stale data',
          message: state == ManagerViewState.offline
              ? child == null
                    ? 'No cached records are available. Reconnect and refresh.'
                    : 'Showing the last fetched records. Authoritative actions are paused.'
              : 'These records need a refresh before a decision. Authoritative actions are paused.',
          icon: state == ManagerViewState.offline
              ? Icons.cloud_off_outlined
              : Icons.schedule,
          caution: true,
          action: TextButton(
            onPressed: onRetry,
            child: const Text('Refresh records'),
          ),
        ),
        if (child != null) ...[const SizedBox(height: 16), child!],
      ],
    ),
    ManagerViewState.success => child ?? const SizedBox.shrink(),
  };
}

class ManagerStateSkeleton extends StatelessWidget {
  const ManagerStateSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading manager records',
    child: const ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FrostedSkeleton(height: 48),
          SizedBox(height: 16),
          FrostedSkeletonCard(lines: 2),
          SizedBox(height: 12),
          FrostedSkeletonCard(lines: 2),
        ],
      ),
    ),
  );
}
