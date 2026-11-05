import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';

class PublicRecordFrame extends StatelessWidget {
  const PublicRecordFrame({
    super.key,
    required this.child,
    this.textFirst = false,
    this.onToggleView,
    this.onRefresh,
  });
  final Widget child;
  final bool textFirst;
  final VoidCallback? onToggleView;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      backgroundColor: textFirst ? Colors.white : Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      const TankBrand(surface: 'VERIFY'),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (onToggleView != null)
                            TextButton.icon(
                              onPressed: onToggleView,
                              icon: Icon(
                                textFirst
                                    ? Icons.view_agenda_outlined
                                    : Icons.text_snippet_outlined,
                              ),
                              label: Text(
                                textFirst ? 'Standard view' : 'Text-first view',
                              ),
                            ),
                          if (onRefresh != null)
                            IconButton.filledTonal(
                              tooltip: 'Refresh public record',
                              onPressed: onRefresh,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return textFirst ? screen : TankBackdrop(child: screen);
  }
}
