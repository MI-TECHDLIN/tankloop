import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'runtime.dart';
import 'field_content.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

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

  Future<void> resolve(String raw) async {
    if (resolving) return;
    setState(() {
      resolving = true;
      error = null;
    });
    try {
      final runtime = ref.read(runtimeProvider);
      if (runtime.accessRevoked) return;
      final point = await resolveFieldQr(
        raw,
        repository: runtime.repository,
        dashboard: runtime.dashboard,
        online: runtime.online,
      );
      if (mounted) {
        context.go('/point/${point.id}');
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is FormatException
              ? failure.message
              : failure is RepositoryFailure
              ? failure.message
              : 'Could not verify this QR. Check the connection and retry.',
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
            FieldContent(
              runtime: ref.watch(runtimeProvider),
              empty: () => ref.read(runtimeProvider).dashboard.points.isEmpty,
              loading: resolving,
              error: error,
              onRetry: () => resolve(manual.text),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        height: 280,
                        child: MobileScanner(
                          controller: scanner,
                          errorBuilder: (context, error) => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: NoticeCard(
                                title: 'Camera unavailable',
                                message:
                                    'Allow camera access in Android settings, or use the manual code below.',
                              ),
                            ),
                          ),
                          onDetect: (capture) {
                            final value =
                                capture.barcodes.firstOrNull?.rawValue;
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
                        onPressed: resolving
                            ? null
                            : () => resolve(manual.text),
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
                    label: Text(
                      resolving ? 'Opening point…' : 'Use manual code',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
