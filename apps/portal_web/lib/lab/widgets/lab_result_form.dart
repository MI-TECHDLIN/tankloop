import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import '../lab_controller.dart';
import 'lab_form_support.dart';
import 'lab_measurement_fields.dart';

class LabResultForm extends StatefulWidget {
  const LabResultForm({
    super.key,
    required this.record,
    required this.controller,
  });
  final LabRecord record;
  final LabController controller;
  @override
  State<LabResultForm> createState() => _LabResultFormState();
}

class _LabResultFormState extends State<LabResultForm> {
  final form = GlobalKey<FormState>();
  var measurement = GlobalKey<LabMeasurementFieldsState>();
  final reason = TextEditingController();
  late int version = widget.record.version;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    widget.controller.submit(
      record: widget.record,
      expectedVersion: version,
      action: LabAction.enterResult,
      payload: measurement.currentState!.reading.toJson(),
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
            'Enter laboratory result',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Preserve what the laboratory reported. Entry alone does not attest or publish a finding.',
            style: TextStyle(color: TankColors.muted),
          ),
          const SizedBox(height: 20),
          LabVersionNotice(
            record: widget.record,
            version: version,
            onReset: () => setState(() {
              version = widget.record.version;
              reason.clear();
              measurement = GlobalKey<LabMeasurementFieldsState>();
            }),
          ),
          LabMeasurementFields(
            key: measurement,
            method: widget.record.sample.intendedMethod,
            enabled: widget.controller.canWrite,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('lab-reason'),
            controller: reason,
            enabled: widget.controller.canWrite,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Entry note (required)',
            ),
            validator: labRequired,
          ),
          const SizedBox(height: 20),
          LabCommandButton(
            controller: widget.controller,
            label: 'Submit result for review',
            enabled: version == widget.record.version,
            onSubmit: submit,
          ),
        ],
      ),
    ),
  );
}
