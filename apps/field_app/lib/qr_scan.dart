import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'runtime.dart';

class QrScanPage extends ConsumerStatefulWidget {
  const QrScanPage({super.key});
  @override
  ConsumerState<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends ConsumerState<QrScanPage> {
  final manual = TextEditingController();
  final scanner = MobileScannerController();
  String? error;
  bool resolving = false;

  @override
  void dispose() {
    manual.dispose();
    scanner.dispose();
    super.dispose();
  }

  String _token(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return trimmed;
  }

  Future<void> resolve(String raw) async {
    final token = _token(raw);
    if (!RegExp(r'^[a-f0-9]{32,128}$').hasMatch(token)) {
      setState(
        () => error = 'Enter the opaque point code printed with the QR.',
      );
      return;
    }
    setState(() {
      resolving = true;
      error = null;
    });
    try {
      final runtime = ref.read(runtimeProvider);
      final record = await runtime.repository.publicRecord(token);
      if (record == null) {
        throw const FormatException(
          'This QR is unknown or revoked. Check the printed point label.',
        );
      }
      final pointId = runtime.dashboard.publicTokens.entries
          .where((entry) => entry.value == token)
          .map((entry) => entry.key)
          .firstOrNull;
      if (pointId == null) {
        throw const FormatException(
          'This point is not assigned to the signed-in field account.',
        );
      }
      final point = runtime.dashboard.points
          .where((item) => item.id == pointId)
          .firstOrNull;
      final task = runtime.dashboard.inspections
          .where((item) => point != null && item.assetId == point.assetId)
          .where((item) => !item.isSubmitted)
          .firstOrNull;
      if (!mounted) return;
      if (task == null) {
        setState(() {
          resolving = false;
          error =
              '${record.pointLabel} is valid, but no open field task is assigned on this device.';
        });
        return;
      }
      context.go('/inspection/${task.id}');
    } on FormatException catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'The point could not be opened. Keep the code and retry when connected.',
        );
      }
    } finally {
      if (mounted) setState(() => resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) => TankBackdrop(
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Open water point'),
        leading: IconButton(
          tooltip: 'Back to Today',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 280,
                  child: MobileScanner(
                    controller: scanner,
                    onDetect: (capture) {
                      final value = capture.barcodes.firstOrNull?.rawValue;
                      if (value != null && !resolving) {
                        unawaited(resolve(value));
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Point the camera at the opaque TankLoop QR. Revoked or unknown codes never open a record.',
              style: TextStyle(color: TankColors.muted),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: manual,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Manual point code',
                errorText: error,
                suffixIcon: IconButton(
                  tooltip: 'Open point code',
                  onPressed: resolving ? null : () => resolve(manual.text),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
              onSubmitted: resolving ? null : resolve,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: resolving ? null : () => resolve(manual.text),
              icon: resolving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.key_rounded),
              label: Text(resolving ? 'Opening point…' : 'Use manual code'),
            ),
          ],
        ),
      ),
    ),
  );
}
