import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tankloop_design_system/design_system.dart';

import '../runtime.dart';
import 'handover.dart';

class PrepareHandoverButton extends StatelessWidget {
  const PrepareHandoverButton({
    super.key,
    required this.kind,
    required this.id,
    required this.label,
  });
  final String kind;
  final String id;
  final String label;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.edit_note_rounded),
    label: const Text('Prepare handover'),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HandoverPage(kind: kind, id: id, label: label),
      ),
    ),
  );
}

class HandoverPage extends ConsumerStatefulWidget {
  const HandoverPage({
    super.key,
    required this.kind,
    required this.id,
    required this.label,
  });
  final String kind;
  final String id;
  final String label;
  @override
  ConsumerState<HandoverPage> createState() => _HandoverPageState();
}

class _HandoverPageState extends ConsumerState<HandoverPage> {
  late final HandoverController controller;
  final editor = TextEditingController();

  @override
  void initState() {
    super.initState();
    final runtime = ref.read(runtimeProvider);
    controller = HandoverController(
      service: ref.read(handoverServiceProvider),
      store: runtime.store,
      storageKey: handoverStorageKey(
        runtime.identity,
        runtime.dashboard.scope.facilityId,
      ),
      actorId: runtime.dashboard.actorId,
      kind: widget.kind,
      id: widget.id,
      canConnect: () => runtime.online && !runtime.syncPaused,
      hasAccess: () => !runtime.accessRevoked,
    );
    controller.addListener(_updateEditor);
    controller.load();
  }

  void _updateEditor() {
    if (editor.text != controller.wording) editor.text = controller.wording;
  }

  @override
  void dispose() {
    controller.dispose();
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([controller, runtime]),
      builder: (context, _) {
        final draft = controller.draft;
        final online = runtime.online && !runtime.syncPaused;
        return Scaffold(
          backgroundColor: TankColors.canvas,
          appBar: AppBar(title: const Text('Prepare handover')),
          body: SafeArea(
            child: runtime.accessRevoked
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Your access has changed. Return to your assignments.',
                    ),
                  )
                : ListView(
                    key: const Key('handover-scroll'),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        widget.kind == 'point'
                            ? (draft?.snapshot['label'] as String? ??
                                  widget.label)
                            : widget.label,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A clear update, ready for your review.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Prepare a short update from synced records. Check the sources, edit the wording, then save a private draft on this device.',
                      ),
                      const SizedBox(height: 16),
                      if (!online) ...[
                        _panel(
                          'You are offline',
                          const Text(
                            'You can read and edit your existing wording. Connect to prepare a new draft or check sources before saving.',
                          ),
                        ),
                        TextButton(
                          onPressed: runtime.refreshing
                              ? null
                              : runtime.refresh,
                          child: const Text('Refresh connection'),
                        ),
                      ],
                      if (controller.failure != null)
                        _panel(
                          'Draft needs attention',
                          Text(controller.failure!.message),
                          caution: true,
                        ),
                      FilledButton.icon(
                        onPressed: controller.busy || !online
                            ? null
                            : controller.generate,
                        icon: const Icon(Icons.edit_note_rounded),
                        label: Text(
                          draft == null
                              ? 'Prepare AI draft'
                              : 'Prepare a new draft',
                        ),
                      ),
                      if (controller.busy) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(
                          semanticsLabel:
                              'Checking sources and preparing your draft',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Checking the current records. Your existing wording is retained.',
                          ),
                        ),
                      ],
                      if (draft != null) ...[
                        const SizedBox(height: 20),
                        _panel(
                          'AI draft - review required',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'What happened?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              for (final fact in draft.highlights) ...[
                                const SizedBox(height: 12),
                                Text(fact['text'] as String),
                                _sourceButton(
                                  draft,
                                  fact['source_id'] as String,
                                ),
                              ],
                            ],
                          ),
                        ),
                        _panel(
                          'What is missing?',
                          _steps(draft, draft.gaps),
                          caution: true,
                        ),
                        _panel(
                          'What happens next?',
                          _steps(draft, draft.steps),
                        ),
                        _panel(
                          'What this update cannot tell you',
                          Text(draft.limitation),
                        ),
                        TextField(
                          controller: editor,
                          enabled: !controller.busy,
                          minLines: 5,
                          maxLines: null,
                          maxLength: 6000,
                          decoration: const InputDecoration(
                            labelText: 'Your draft update',
                            alignLabelWithHint: true,
                            helperText:
                                'Check your wording against the sources. Unsaved edits are lost when you leave this screen.',
                            helperMaxLines: 5,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: controller.edit,
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: controller.reviewed,
                          onChanged:
                              controller.busy || controller.mustRegenerate
                              ? null
                              : (value) =>
                                    controller.confirmReview(value ?? false),
                          title: const Text(
                            'I reviewed the wording, dated sources and missing steps.',
                          ),
                          subtitle: const Text(
                            'Saving keeps a private draft. It does not publish an update, attest a result or close a case.',
                          ),
                        ),
                        FilledButton(
                          onPressed: controller.canSave
                              ? controller.save
                              : null,
                          child: const Text('Save reviewed draft on device'),
                        ),
                        if (controller.savedAt != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              controller.hasUnsavedEdits
                                  ? 'Your earlier reviewed draft is saved. These edits have not been saved.'
                                  : 'Reviewed draft saved on this device at ${controller.savedAt}. Sources may have changed since that check.',
                              key: const Key('handover-saved'),
                            ),
                          ),
                        if (controller.previousWording != null)
                          ExpansionTile(
                            title: const Text('Your previous wording'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: SelectableText(
                                  controller.previousWording!,
                                ),
                              ),
                            ],
                          ),
                        ExpansionTile(
                          title: Text(
                            'All source details (${draft.sources.length})',
                          ),
                          children: [
                            for (final source in draft.sources)
                              _sourceButton(draft, source['id'] as String),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Prepared ${draft.generatedAt}\nGroq · ${draft.model}\nOnly synced records are included. Recheck after 30 minutes.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: TankColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _panel(String title, Widget child, {bool caution = false}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: caution ? const Color(0xfffff5df) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: caution ? const Color(0xffdec898) : const Color(0xffdae4e6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _steps(HandoverDraft draft, List<Json> steps) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final step in steps)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step['text'] as String),
              for (final id in step['source_ids'] as List)
                _sourceButton(draft, id as String),
            ],
          ),
        ),
    ],
  );

  Widget _sourceButton(HandoverDraft draft, String id) {
    final source = draft.sources.where((s) => s['id'] == id).firstOrNull;
    if (source == null) {
      return const Text('Source unavailable. Prepare a new draft.');
    }
    final kind = (source['kind'] as String).replaceAll('_', ' ');
    return TextButton.icon(
      icon: const Icon(Icons.source_outlined, size: 18),
      label: Text('See $kind source'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .7,
          maxChildSize: .95,
          builder: (context, scroll) => ListView(
            key: const Key('handover-source-scroll'),
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Dated $kind record',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Source snapshot used for this draft. These are recorded facts; this assistant has not checked the water.',
              ),
              const SizedBox(height: 16),
              SelectableText(
                'Record ID: ${source['record_id']}\nSource revision: ${source['revision']}',
              ),
              for (final field in (source['fields'] as Json).entries)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${field.key.replaceAll('_', ' ')}: ${field.value ?? 'Not recorded'}',
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Notes, personal contacts and attachments are excluded from AI assistance.',
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close source'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
