import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_localization/localization.dart';
import '../lab_controller.dart';

class LabScreenFrame extends StatelessWidget {
  const LabScreenFrame({
    super.key,
    required this.controller,
    required this.title,
    required this.description,
    required this.isEmpty,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.builder,
  });
  final LabController controller;
  final String title;
  final String description;
  final bool Function(LabWorkspace) isEmpty;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(LabWorkspace) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final data = controller.workspace;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: TankColors.muted)),
          const SizedBox(height: 24),
          if (data?.facility.isSimulated == true &&
              controller.phase != LabPhase.permissionDenied) ...[
            const SimulationNotice(),
            const SizedBox(height: 20),
          ],
          if (controller.phase == LabPhase.loading)
            LabLoadingSkeleton(label: title)
          else if (controller.phase == LabPhase.permissionDenied)
            NoticeCard(
              title: 'Laboratory access required',
              message:
                  controller.message ??
                  'Only an active laboratory reviewer assigned to this facility can open its records.',
              icon: Icons.lock_outline_rounded,
              action: _retry(),
            )
          else ...[
            if (controller.refreshing) ...[
              const LinearProgressIndicator(
                semanticsLabel: 'Refreshing lab records',
              ),
              const SizedBox(height: 16),
            ],
            if (controller.phase == LabPhase.error) ...[
              NoticeCard(
                title: '$title unavailable',
                message:
                    controller.message ??
                    'The lab service could not load these records.',
                icon: Icons.error_outline_rounded,
                caution: true,
                action: _retry(),
              ),
              const SizedBox(height: 16),
            ],
            if (controller.phase == LabPhase.offline ||
                controller.phase == LabPhase.stale) ...[
              NoticeCard(
                title: controller.phase == LabPhase.offline
                    ? 'Offline - read-only'
                    : 'Stale record - refresh required',
                message: controller.phase == LabPhase.offline
                    ? 'Cached records may be incomplete. Intake, result entry, attestation and corrections require a server connection.'
                    : 'This view is more than five minutes old or changed on the server. Refresh and review before making a decision.',
                icon: controller.phase == LabPhase.offline
                    ? Icons.cloud_off_outlined
                    : Icons.history_rounded,
                caution: true,
                action: _retry(),
              ),
              const SizedBox(height: 16),
            ],
            if (controller.receipt case final receipt?) ...[
              NoticeCard(
                title: receipt.isSimulated
                    ? 'Server receipt recorded - simulated data'
                    : 'Server receipt recorded',
                message:
                    '${switch (receipt.action) {
                      LabAction.accept => 'Sample accepted for testing.',
                      LabAction.reject => 'Sample rejected. No valid result from this sample.',
                      LabAction.enterResult => 'Result entered. Authorized review is still required.',
                      LabAction.attest => 'Result attested with a linked report. Publication is a separate decision.',
                      LabAction.correct => 'Superseding revision created. The earlier result is retained.',
                    }}\n${recordTime(receipt.recordedAt, timezone: data?.facility.timezone ?? 'UTC')} · Receipt ${receipt.eventId}',
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 16),
            ],
            if (controller.commandError case final error?) ...[
              NoticeCard(
                title: 'Action not confirmed',
                message: error,
                caution: true,
                action: controller.hasPendingCommand
                    ? TextButton.icon(
                        onPressed: controller.canRetry
                            ? controller.retryPending
                            : null,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Retry unconfirmed action'),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
            ],
            if (data == null)
              const NoticeCard(
                title: 'No cached laboratory records',
                message:
                    'Connect to load the facility records. No result or review status can be inferred.',
              )
            else if (isEmpty(data))
              NoticeCard(
                title: emptyTitle,
                message: emptyMessage,
                icon: Icons.inbox_outlined,
              )
            else
              KeyedSubtree(
                key: const ValueKey('lab-record-content'),
                child: builder(data),
              ),
          ],
        ],
      );
    },
  );

  Widget _retry() => TextButton.icon(
    onPressed: controller.busy || controller.refreshing
        ? null
        : () => controller.refresh(),
    icon: const Icon(Icons.refresh_rounded),
    label: const Text('Refresh lab records'),
  );
}

class LabLoadingSkeleton extends StatelessWidget {
  const LabLoadingSkeleton({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading $label',
    container: true,
    liveRegion: true,
    child: Column(
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              FractionallySizedBox(
                widthFactor: .4,
                alignment: Alignment.centerLeft,
                child: FrostedSkeleton(height: 24),
              ),
              SizedBox(height: 20),
              FrostedSkeleton(height: 48),
              SizedBox(height: 12),
              FractionallySizedBox(
                widthFactor: .7,
                alignment: Alignment.centerLeft,
                child: FrostedSkeleton(),
              ),
            ],
          ),
        ),
        for (var i = 0; i < 3; i++) ...[
          const SizedBox(height: 16),
          const GlassCard(
            child: Row(
              children: [
                FrostedSkeleton(width: 40, height: 40),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FrostedSkeleton(height: 20),
                      SizedBox(height: 12),
                      FractionallySizedBox(
                        widthFactor: .6,
                        alignment: Alignment.centerLeft,
                        child: FrostedSkeleton(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
