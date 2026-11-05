import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import 'package:tankloop_shared_forms/shared_forms.dart';
import 'sync_status.dart';
import 'evidence_photo.dart';
import 'field_content.dart';
import 'runtime.dart';

class InspectionPage extends ConsumerStatefulWidget {
  const InspectionPage({super.key, required this.taskId});
  final String taskId;
  @override
  ConsumerState<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends ConsumerState<InspectionPage> {
  Map<String, InspectionAnswer> answers = {};
  late final TextEditingController notes;
  bool saving = false;
  bool submitting = false;
  bool capturing = false;
  String? error;
  List<InspectionEvidence> evidence = [];
  int saveGeneration = 0;
  String? questionId;
  @override
  void initState() {
    super.initState();
    final entry = ref.read(runtimeProvider).outbox.forTask(widget.taskId);
    answers = {...?entry?.command.answers};
    notes = TextEditingController(text: entry?.command.notes ?? '');
    evidence = [...?entry?.command.evidence];
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<bool> save(InspectionTask task) async {
    final runtime = ref.read(runtimeProvider);
    final generation = ++saveGeneration;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await runtime.outbox.save(
        task: task,
        answers: answers,
        notes: notes.text,
        evidence: evidence,
        observedAt: task.isSimulated
            ? runtime.dashboard.asOf
            : DateTime.now().toUtc(),
      );
      return true;
    } catch (_) {
      if (mounted && generation == saveGeneration) {
        setState(
          () => error =
              'Could not save on this device. Keep this screen open and retry Save draft.',
        );
      }
      return false;
    } finally {
      if (mounted && generation == saveGeneration) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> captureEvidence(InspectionTask task) async {
    if (capturing) return;
    setState(() => capturing = true);
    try {
      if (!await save(task)) return;
      final runtime = ref.read(runtimeProvider);
      await runtime.photoCapture.capture(
        id: task.id,
        workOrder: false,
        questionId: questionId,
      );
      if (mounted) {
        setState(
          () =>
              evidence = [...runtime.outbox.forTask(task.id)!.command.evidence],
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Photo evidence could not be captured. Your inspection draft is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

  Future<void> submit(InspectionTask task, ChecklistTemplate template) async {
    if (submitting || capturing) return;
    setState(() => submitting = true);
    try {
      if (!await save(task)) return;
      final runtime = ref.read(runtimeProvider);
      await runtime.outbox.enqueue(task.id, template);
      await runtime.sync();
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is RuleViolation
              ? failure.message
              : 'Your local inspection is retained. Open Activity to retry the upload.',
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: runtime,
      builder: (context, _) {
        final task = runtime.dashboard.inspections
            .where((t) => t.id == widget.taskId)
            .firstOrNull;
        if (task == null || runtime.accessRevoked) {
          return TankBackdrop(
            child: Scaffold(
              appBar: AppBar(title: const Text('Inspection')),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  FieldContent(
                    runtime: runtime,
                    empty: () => task == null,
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }
        final template = runtime.dashboard.templateFor(task);
        return AnimatedBuilder(
          animation: Listenable.merge([runtime, runtime.outbox]),
          builder: (context, _) {
            final entry = runtime.outbox.forTask(task.id);
            final locked =
                task.isSubmitted ||
                entry != null && entry.state != DraftState.draft;
            final complete = template.questions
                .where((q) => q.required)
                .every((q) => answers.containsKey(q.id));
            return TankBackdrop(
              child: PopScope(
                canPop: !saving && !submitting && !capturing,
                child: Scaffold(
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    leading: IconButton(
                      tooltip: 'Back to Today',
                      onPressed: saving || submitting || capturing
                          ? null
                          : () => context.go('/'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    title: const Text(
                      'Inspection',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: StatusPill(
                          saving
                              ? 'Saving…'
                              : entry == null
                              ? 'Not yet saved'
                              : entryLabel(entry),
                          compact: true,
                          icon: saving ? Icons.more_horiz : Icons.save_outlined,
                        ),
                      ),
                    ],
                  ),
                  body: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                          child: FieldContent(
                            runtime: runtime,
                            empty: () => false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (task.isSimulated) ...[
                                  const SimulationNotice(compact: true),
                                  const SizedBox(height: 24),
                                ],
                                Text(
                                  runtime.dashboard.assetFor(task).label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${runtime.dashboard.facility.label} · Checklist v${template.version}',
                                  style: const TextStyle(
                                    color: TankColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Due ${recordTime(task.dueAt)}',
                                  style: const TextStyle(
                                    color: TankColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const NoticeCard(
                                  title: 'Observe, don’t infer',
                                  message:
                                      'Inspection risk observed does not imply a test result. Unknown is a valid answer when you cannot inspect an item.',
                                  icon: Icons.visibility_outlined,
                                ),
                                const SizedBox(height: 24),
                                if (!locked) ...[
                                  Text(
                                    '${answers.length} of ${template.questions.length} items answered',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  LinearProgressIndicator(
                                    value:
                                        answers.length /
                                        template.questions.length,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(8),
                                    semanticsLabel: 'Checklist completion',
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                if (entry != null &&
                                    entry.state != DraftState.draft) ...[
                                  NoticeCard(
                                    title: entryLabel(entry),
                                    message: entry.receipt != null
                                        ? '${runtime.config.mode == AppMode.simulation ? 'Simulation' : 'Server'} acknowledged version ${entry.receipt!.version} at ${recordTime(entry.receipt!.receivedAt)}. This inspection is an observation, not a laboratory finding.'
                                        : entry.error ??
                                              'Your inspection is saved on this device. It remains pending until a receipt is received.',
                                    icon: entry.receipt != null
                                        ? Icons.receipt_long_outlined
                                        : Icons.cloud_upload_outlined,
                                    caution: entry.state == DraftState.blocked,
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                InspectionChecklist(
                                  template: template,
                                  answers: answers,
                                  readOnly: locked,
                                  onChanged: (value) {
                                    setState(() => answers = value);
                                    unawaited(save(task));
                                  },
                                ),
                                TextField(
                                  controller: notes,
                                  readOnly: locked,
                                  maxLines: 3,
                                  maxLength: 4000,
                                  decoration: const InputDecoration(
                                    labelText: 'Visit notes (optional)',
                                    hintText:
                                        'Add useful context for the next person.',
                                  ),
                                  onChanged: (_) => unawaited(save(task)),
                                ),
                                const SizedBox(height: 20),
                                if (evidence.isNotEmpty) ...[
                                  const Text(
                                    'Photo evidence',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 92,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: evidence.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 10),
                                      itemBuilder: (_, index) => Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: EvidencePhoto(
                                              key: ValueKey(evidence[index].id),
                                              photo: evidence[index],
                                              photos: runtime.outbox.photos,
                                            ),
                                          ),
                                          Positioned(
                                            right: 4,
                                            top: 4,
                                            child: CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.black54,
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (!locked) ...[
                                  DropdownButtonFormField<String>(
                                    initialValue: questionId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Photo relates to',
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('Whole inspection'),
                                      ),
                                      for (final q in template.questions)
                                        DropdownMenuItem(
                                          value: q.id,
                                          child: Text(
                                            q.label,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => questionId = value),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: saving || submitting || capturing
                                        ? null
                                        : () => captureEvidence(task),
                                    icon: const Icon(Icons.camera_alt_outlined),
                                    label: Text(
                                      evidence.isEmpty
                                          ? 'Add photo evidence'
                                          : 'Add another photo',
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Text(
                                  template.source,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: TankColors.muted,
                                  ),
                                ),
                                if (error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: NoticeCard(
                                      title: 'Please review',
                                      message: error!,
                                      caution: true,
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                if (!locked) ...[
                                  OutlinedButton.icon(
                                    onPressed: saving || submitting || capturing
                                        ? null
                                        : () => save(task),
                                    icon: const Icon(Icons.save_outlined),
                                    label: const Text('Save draft'),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed:
                                        !complete ||
                                            saving ||
                                            submitting ||
                                            capturing
                                        ? null
                                        : () => submit(task, template),
                                    icon: const Icon(
                                      Icons.arrow_upward_rounded,
                                    ),
                                    label: Text(
                                      submitting
                                          ? 'Recording…'
                                          : runtime.online
                                          ? 'Submit inspection'
                                          : 'Queue inspection',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    complete
                                        ? 'A submitted inspection is retained with its issued checklist version.'
                                        : 'Answer every required item before submitting. Drafts can be saved at any time.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: TankColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ] else
                                  FilledButton(
                                    onPressed: () => context.go('/'),
                                    child: const Text('Back to Today'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
