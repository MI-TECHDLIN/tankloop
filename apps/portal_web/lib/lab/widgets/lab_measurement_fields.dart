import 'package:flutter/material.dart';
import 'package:tankloop_domain/domain.dart';
import 'lab_form_support.dart';
import 'lab_record_widgets.dart';

class LabMeasurementFields extends StatefulWidget {
  const LabMeasurementFields({
    super.key,
    required this.method,
    required this.enabled,
    this.initial,
    this.fixedScope = false,
  });
  final String method;
  final bool enabled;
  final Measurement? initial;
  final bool fixedScope;
  @override
  State<LabMeasurementFields> createState() => LabMeasurementFieldsState();
}

class LabMeasurementFieldsState extends State<LabMeasurementFields> {
  late Indicator indicator = widget.initial?.indicator ?? Indicator.eColi;
  late ResultUnit unit = widget.initial?.unit ?? ResultUnit.cfuPer100ml;
  late final value = TextEditingController(
    text: widget.initial == null ? '' : labNumber(widget.initial!.value),
  );
  late final limit = TextEditingController(
    text: widget.initial == null
        ? ''
        : labNumber(widget.initial!.detectionLimit),
  );

  Measurement get reading => Measurement(
    indicator: indicator,
    method: widget.method,
    value: double.parse(value.text.trim()),
    unit: unit,
    detectionLimit: double.parse(limit.text.trim()),
  );

  @override
  void dispose() {
    value.dispose();
    limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<Indicator>(
        key: const ValueKey('lab-indicator'),
        initialValue: indicator,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Indicator (required)'),
        items: Indicator.values
            .map((i) => DropdownMenuItem(value: i, child: Text(i.label)))
            .toList(),
        onChanged: !widget.enabled || widget.fixedScope
            ? null
            : (selected) => setState(() {
                if (selected == null) return;
                indicator = selected;
                if (selected == Indicator.hydrogenSulfide &&
                    unit != ResultUnit.presenceAbsence) {
                  unit = ResultUnit.presenceAbsence;
                  value.clear();
                }
              }),
      ),
      const SizedBox(height: 16),
      TextFormField(
        key: const ValueKey('lab-method'),
        initialValue: widget.method,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Method from sample plan',
          helperText: 'Retain the exact method and sample scope.',
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<ResultUnit>(
        key: ValueKey('lab-unit-${unit.name}'),
        initialValue: unit,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Reported units (required)',
        ),
        items: ResultUnit.values
            .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
            .toList(),
        onChanged:
            !widget.enabled ||
                widget.fixedScope ||
                indicator == Indicator.hydrogenSulfide
            ? null
            : (selected) => setState(() {
                if (selected != null && selected != unit) {
                  unit = selected;
                  value.clear();
                }
              }),
      ),
      const SizedBox(height: 16),
      if (unit == ResultUnit.presenceAbsence)
        DropdownButtonFormField<String>(
          key: const ValueKey('lab-presence'),
          initialValue: value.text.isEmpty ? null : value.text,
          decoration: const InputDecoration(
            labelText: 'Presence / absence (required)',
          ),
          items: const [
            DropdownMenuItem(value: '0', child: Text('Absent (0)')),
            DropdownMenuItem(value: '1', child: Text('Present (1)')),
          ],
          onChanged: widget.enabled
              ? (selected) => value.text = selected ?? ''
              : null,
          validator: labRequired,
        )
      else
        TextFormField(
          key: const ValueKey('lab-value'),
          controller: value,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Result value (required)',
            suffixText: unit.label,
          ),
          validator: labQuantity,
        ),
      const SizedBox(height: 16),
      TextFormField(
        key: const ValueKey('lab-limit'),
        controller: limit,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Detection limit (required)',
          suffixText: unit.label,
          helperText: 'Use the laboratory-reported limit for this assay.',
          helperMaxLines: 2,
        ),
        validator: (v) => labQuantity(v, detectionLimit: true),
      ),
    ],
  );
}

class LabReviewConfirmation extends FormField<bool> {
  LabReviewConfirmation({super.key, required bool enabled})
    : super(
        initialValue: false,
        validator: (checked) => checked == true
            ? null
            : 'Confirm that you reviewed this sample and its signed report.',
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: field.value,
              onChanged: enabled ? field.didChange : null,
              title: const Text(
                'I reviewed the sample identity, method, units, detection limit and signed report.',
                style: TextStyle(fontSize: 14),
              ),
            ),
            if (field.hasError)
              Text(
                field.errorText!,
                style: TextStyle(
                  color: Theme.of(field.context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      );
}
