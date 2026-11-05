import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import '../lab_controller.dart';
import 'lab_form_support.dart';
import 'lab_measurement_fields.dart';

class LabRevisionForm extends StatefulWidget {
  const LabRevisionForm({
    super.key,
    required this.record,
    required this.controller,
    required this.onRevised,
  });
  final LabRecord record;
  final LabController controller;
  final ValueChanged<String> onRevised;
  @override
  State<LabRevisionForm> createState() => _LabRevisionFormState();
}

class _LabRevisionFormState extends State<LabRevisionForm> {
  final form = GlobalKey<FormState>();
  var measurement = GlobalKey<LabMeasurementFieldsState>();
  final report = TextEditingController();
  final reason = TextEditingController();
  late int version = widget.record.version;
  @override
  void dispose() {
    report.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final reading = measurement.currentState!.reading;
    final receipt = await widget.controller.submit(
      record: widget.record,
      expectedVersion: version,
      action: LabAction.correct,
      payload: {
        'value': reading.value,
        'detection_limit': reading.detectionLimit,
        'report_ref': report.text.trim(),
      },
      reason: reason.text.trim(),
    );
    if (mounted && receipt != null) widget.onRevised(receipt.resultId);
  }

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create superseding revision',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'The original value, signed report and review remain available. Keep the same sample, indicator, method and units.',
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
              measurement = GlobalKey<LabMeasurementFieldsState>();
              form.currentState!.reset();
            }),
          ),
          LabMeasurementFields(
            key: measurement,
            method: widget.record.sample.intendedMethod,
            initial: widget.record.measurement,
            fixedScope: true,
            enabled: widget.controller.canWrite,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('lab-report'),
            controller: report,
            enabled: widget.controller.canWrite,
            decoration: const InputDecoration(
              labelText: 'Corrected signed report (required)',
              hintText: 'https://...',
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
              labelText: 'Correction reason (required)',
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
            label: 'Attest superseding revision',
            enabled: version == widget.record.version,
            onSubmit: submit,
          ),
        ],
      ),
    ),
  );
}
