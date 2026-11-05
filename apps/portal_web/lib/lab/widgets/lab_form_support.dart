import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import '../lab_controller.dart';

String? labRequired(String? value) => value == null || value.trim().isEmpty
    ? 'This field is required.'
    : value.trim().length > 4000
    ? 'Use 4,000 characters or fewer.'
    : null;

String? labQuantity(String? value, {bool detectionLimit = false}) {
  final number = double.tryParse(value?.trim() ?? '');
  if (number == null ||
      !number.isFinite ||
      number >= 1000000000 ||
      (detectionLimit ? number <= 0 : number < 0)) {
    return detectionLimit
        ? 'Enter a positive, finite detection limit below 1,000,000,000.'
        : 'Enter a non-negative, finite value below 1,000,000,000.';
  }
  return null;
}

String? labReportReference(String? value, {required bool simulated}) {
  if (labRequired(value) case final error?) return error;
  final text = value!.trim();
  final uri = Uri.tryParse(text);
  if (uri == null ||
      RegExp(r'\s').hasMatch(text) ||
      uri.userInfo.isNotEmpty ||
      !((uri.scheme == 'https' && uri.host.isNotEmpty) ||
          (simulated && uri.scheme == 'simulation' && uri.hasAuthority))) {
    return simulated
        ? 'Use an HTTPS signed report link or a simulation:// reference.'
        : 'Use an HTTPS link to the signed laboratory report.';
  }
  return null;
}

class LabCommandButton extends StatelessWidget {
  const LabCommandButton({
    super.key,
    required this.controller,
    required this.label,
    required this.onSubmit,
    this.enabled = true,
  });
  final LabController controller;
  final String label;
  final VoidCallback onSubmit;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!controller.repository.serverBacked) ...[
        const Text(
          'Standalone playback is read-only. Connect a Supabase lab session to record intake, enter results or attest a signed report.',
          style: TextStyle(fontSize: 13, color: TankColors.muted),
        ),
        const SizedBox(height: 16),
      ],
      FilledButton.icon(
        onPressed: controller.canWrite && enabled ? onSubmit : null,
        icon: Icon(
          controller.busy ? Icons.sync_rounded : Icons.arrow_forward_rounded,
          size: 18,
        ),
        label: Text(controller.busy ? 'Waiting for server receipt...' : label),
      ),
    ],
  );
}

class LabVersionNotice extends StatelessWidget {
  const LabVersionNotice({
    super.key,
    required this.record,
    required this.version,
    required this.onReset,
  });
  final LabRecord record;
  final int version;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) => record.version == version
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: NoticeCard(
            title: 'A newer version is available',
            message:
                'Your entry is still in this tab. Review the current evidence before replacing this draft.',
            caution: true,
            action: TextButton(
              onPressed: onReset,
              child: const Text('Use latest record and reset draft'),
            ),
          ),
        );
}
