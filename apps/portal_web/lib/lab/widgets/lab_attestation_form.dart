import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import '../lab_controller.dart';
import 'lab_form_support.dart';
import 'lab_measurement_fields.dart';

class LabAttestationForm extends StatefulWidget {
  const LabAttestationForm({
    super.key,
    required this.record,
    required this.controller,
  });
  final LabRecord record;
  final LabController controller;
  @override
  State<LabAttestationForm> createState() => _LabAttestationFormState();
}

class _LabAttestationFormState extends State<LabAttestationForm> {
  final form = GlobalKey<FormState>();
  final report = TextEditingController();
  final reason = TextEditingController();
  late int version = widget.record.version;
  @override
  void dispose() {
    report.dispose();
    reason.dispose();
    super.dispose();
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    widget.controller.submit(
      record: widget.record,
      expectedVersion: version,
      action: LabAction.attest,
      payload: {'report_ref': report.text.trim()},
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
            'Authorized attestation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Review the exact evidence, then link the signed laboratory report. The server records the reviewer and timestamp.',
            style: TextStyle(color: TankColors.muted),
          ),
          const SizedBox(height: 20),
          LabVersionNotice(
            record: widget.record,
            version: version,
            onReset: () => setState(() {
              version = widget.record.version;
              report.clear();
              reason.clear();
              form.currentState!.reset();
            }),
          ),
          TextFormField(
            key: const ValueKey('lab-report'),
            controller: report,
            enabled: widget.controller.canWrite,
            decoration: const InputDecoration(
              labelText: 'Signed report reference (required)',
              hintText: 'https://...',
              helperText:
                  'Link the signed report held in your authorized document service.',
              helperMaxLines: 2,
            ),
            validator: (value) => labReportReference(
              value,
              simulated: widget.record.sample.isSimulated,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('lab-reason'),
            controller: reason,
            enabled: widget.controller.canWrite,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Review note (required)',
            ),
            validator: labRequired,
          ),
          const SizedBox(height: 12),
          LabReviewConfirmation(
            key: ValueKey(version),
            enabled: widget.controller.canWrite,
          ),
          const SizedBox(height: 20),
          LabCommandButton(
            controller: widget.controller,
            label: 'Attest result',
            enabled: version == widget.record.version,
            onSubmit: submit,
          ),
        ],
      ),
    ),
  );
}
