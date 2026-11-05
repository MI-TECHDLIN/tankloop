import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'public_notice.dart';
import 'public_point_controller.dart';
import 'public_record_frame.dart';
import 'public_record_skeleton.dart';

class PublicRecordUnavailable extends StatelessWidget {
  const PublicRecordUnavailable({
    super.key,
    required this.phase,
    required this.onRetry,
    this.status,
    this.textFirst = false,
  });
  final PublicPointPhase phase;
  final PublicLookupStatus? status;
  final VoidCallback onRetry;
  final bool textFirst;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon) = switch (phase) {
      PublicPointPhase.offline => (
        "You're offline",
        'Connect and retry to load this point. No record is stored on this device after the page closes. A connection problem makes no water-quality claim.',
        Icons.cloud_off_outlined,
      ),
      PublicPointPhase.permissionDenied => (
        'Public record access unavailable',
        'Permission denied by the record service. Ask the facility manager to check public access, then retry. No current water-quality claim can be made.',
        Icons.lock_outline_rounded,
      ),
      PublicPointPhase.empty when status == PublicLookupStatus.revoked => (
        'This QR label has been revoked',
        'This printed label no longer opens a public record. Ask the facility manager for its replacement. No current water-quality claim can be made from this link.',
        Icons.link_off_rounded,
      ),
      PublicPointPhase.empty => (
        'Point record not found',
        'Check the printed point name and scan its TankLoop QR again. This link does not identify an available public point. No current water-quality claim can be made.',
        Icons.search_off_rounded,
      ),
      _ => (
        'Record service unavailable',
        'We could not load the point record. Check your connection and retry. A failed lookup does not imply anything about water quality.',
        Icons.error_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: PublicNotice(
        textFirst: textFirst,
        title: title,
        message: message,
        icon: icon,
        caution: true,
        action: phase == PublicPointPhase.empty
            ? null
            : FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
      ),
    );
  }
}

/// Shared with route failures and the manager entry screen.
class RecordUnavailable extends StatelessWidget {
  const RecordUnavailable({
    super.key,
    required this.title,
    required this.message,
    this.loading = false,
    this.onRetry,
  });
  final String title;
  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => PublicRecordFrame(
    child: loading
        ? const PublicRecordSkeleton()
        : PublicNotice(
            title: title,
            message: message,
            action: onRetry == null
                ? null
                : FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ),
  );
}
