import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import 'evidence_photo.dart';
import 'field_content.dart';
import 'runtime.dart';
import 'sync_status.dart';

class WorkOrderScreen extends ConsumerStatefulWidget {
  const WorkOrderScreen({super.key, required this.orderId});
  final String orderId;
  @override
  ConsumerState<WorkOrderScreen> createState() => _WorkOrderScreenState();
}

class _WorkOrderScreenState extends ConsumerState<WorkOrderScreen> {
  final notes = TextEditingController();
  List<InspectionEvidence> photos = [];
  int? editingVersion;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> save(FieldWorkOrder order) async {
    final runtime = ref.read(runtimeProvider);
    await runtime.workOutbox.save(
      order: order,
      actorId: runtime.dashboard.actorId,
      notes: notes.text,
      observedAt: DateTime.now().toUtc(),
      evidence: photos,
    );
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is RuleViolation
              ? failure.message
              : 'Could not finish. Saved work is retained.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([runtime, runtime.workOutbox]),
      builder: (context, _) {
        final order = runtime.dashboard.workOrders
            .where((o) => o.id == widget.orderId)
            .firstOrNull;
        final draft = order == null ? null : runtime.workOutbox.forOrder(order);
        if (order != null && editingVersion != order.version) {
          editingVersion = order.version;
          notes.text = draft?.command.notes ?? '';
          photos = [...?draft?.command.evidence];
        }
        final locked =
            order == null ||
            runtime.accessRevoked ||
            order.assigneeId != runtime.dashboard.actorId ||
            !{
              WorkOrderState.assigned,
              WorkOrderState.inProgress,
              WorkOrderState.rework,
            }.contains(order.state) ||
            draft != null && draft.state != DraftState.draft;
        return TankBackdrop(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Work order'),
              leading: IconButton(
                onPressed: busy ? null : () => context.go('/'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Today',
              ),
            ),
            body: RefreshIndicator(
              onRefresh: () => runtime.refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  FieldContent(
                    runtime: runtime,
                    empty: () => order == null,
                    error: error,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (order != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            order.task,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Recorded state: ${wireName(order.state).replaceAll('_', ' ')}',
                          ),
                          const SizedBox(height: 16),
                          const NoticeCard(
                            title: 'Repair is not resolution',
                            message:
                                'Recording this action does not close the concern. Manager review and any required follow-up remain separate.',
                          ),
                          if (draft != null) ...[
                            const SizedBox(height: 16),
                            NoticeCard(
                              title: draft.error == null
                                  ? draftLabel(draft.state)
                                  : 'Sync failed',
                              message:
                                  draft.error ??
                                  (draft.receipt == null
                                      ? 'Saved on this device. A server receipt confirms delivery.'
                                      : 'Server acknowledged version ${draft.receipt!.version}.'),
                              caution: draft.error != null,
                            ),
                          ],
                          const SizedBox(height: 20),
                          TextField(
                            controller: notes,
                            readOnly: locked || busy,
                            maxLines: 4,
                            maxLength: 4000,
                            decoration: const InputDecoration(
                              labelText: 'Action notes',
                            ),
                            onChanged: (_) => unawaited(
                              save(order).catchError((Object _) {
                                if (mounted) {
                                  setState(
                                    () => error =
                                        'Could not save. Keep this screen open and retry.',
                                  );
                                }
                              }),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final photo in photos)
                                EvidencePhoto(
                                  key: ValueKey(photo.id),
                                  photo: photo,
                                  photos: runtime.workOutbox.photos,
                                ),
                            ],
                          ),
                          if (!locked) ...[
                            OutlinedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => perform(() async {
                                      await save(order);
                                      await runtime.photoCapture.capture(
                                        id: order.id,
                                        workOrder: true,
                                      );
                                      photos = [
                                        ...runtime.workOutbox
                                            .forOrder(order)!
                                            .command
                                            .evidence,
                                      ];
                                    }),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Add step photo'),
                            ),
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => perform(() => save(order)),
                              child: const Text('Save work draft'),
                            ),
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => perform(() async {
                                      await save(order);
                                      await runtime.workOutbox.enqueue(order);
                                      await runtime.sync();
                                    }),
                              child: Text(
                                order.state == WorkOrderState.inProgress
                                    ? 'Record completion'
                                    : 'Record work started',
                              ),
                            ),
                          ],
                          if (draft != null && draft.state == DraftState.pending)
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => perform(runtime.sync),
                              child: const Text('Retry sync'),
                            ),
                          const SectionHeading('Step history on this device'),
                          for (final entry in runtime.workOutbox.entries.where(
                            (e) => e.command.orderId == order.id,
                          ))
                            ListTile(
                              title: Text(
                                wireName(
                                  entry.command.target,
                                ).replaceAll('_', ' '),
                              ),
                              subtitle: Text(
                                '${draftLabel(entry.state)} · ${entry.command.evidence.length} photos',
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}