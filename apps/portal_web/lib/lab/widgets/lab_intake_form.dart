import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import '../lab_controller.dart';
import 'lab_form_support.dart';

class LabIntakeForm extends StatefulWidget {
  const LabIntakeForm({
    super.key,
    required this.record,
    required this.controller,
  });
  final LabRecord record;
  final LabController controller;
  @override
  State<LabIntakeForm> createState() => _LabIntakeFormState();
}

class _LabIntakeFormState extends State<LabIntakeForm> {
  final form = GlobalKey<FormState>();
  final reason = TextEditingController();
  final custody = TextEditingController();
  late int version = widget.record.version;
  bool accept = true;
  @override
  void dispose() {
    reason.dispose();
    custody.dispose();
    super.dispose();
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    widget.controller.submit(
      record: widget.record,
      expectedVersion: version,
      action: accept ? LabAction.accept : LabAction.reject,
      payload: {'custody_note': custody.text.trim()},
      reason: reason.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Record intake decision',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Check the seal, method-specific preservation and recorded transport time.',
            style: TextStyle(color: TankColors.muted),
          ),
          const SizedBox(height: 20),
          LabVersionNotice(
            record: widget.record,
            version: version,
            onReset: () => setState(() {
              version = widget.record.version;
              reason.clear();
              custody.clear();
              form.currentState!.reset();
            }),
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Accept'),
                icon: Icon(Icons.check_circle_outline),
              ),
              ButtonSegment(
                value: false,
                label: Text('Reject'),
                icon: Icon(Icons.block_outlined),
              ),
            ],
            selected: {accept},
            onSelectionChanged: widget.controller.canWrite
                ? (selection) => setState(() => accept = selection.single)
                : null,
          ),
          const SizedBox(height: 16),
          if (widget.record.state == ResultState.collected) ...[
            TextFormField(
              key: const ValueKey('lab-custody'),
              controller: custody,
              enabled: widget.controller.canWrite,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Custody handoff note (required)',
              ),
              validator: labRequired,
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            key: const ValueKey('lab-reason'),
            controller: reason,
            enabled: widget.controller.canWrite,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: accept
                  ? 'Acceptance reason (required)'
                  : 'Rejection reason (required)',
            ),
            validator: labRequired,
          ),
          const SizedBox(height: 16),
          if (!accept) ...[
            const Text(
              'Rejection is final for this sample. No valid result from this sample.',
              style: TextStyle(color: TankColors.amber),
            ),
            const SizedBox(height: 16),
          ],
          LabCommandButton(
            controller: widget.controller,
            label: accept ? 'Accept sample for testing' : 'Reject sample',
            enabled: version == widget.record.version,
            onSubmit: submit,
          ),
        ],
      ),
    ),
  );
}
