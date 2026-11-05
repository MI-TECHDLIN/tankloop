import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'public/public_browser.dart' as browser;
import 'public/public_concern_form.dart';
import 'public/public_point_controller.dart';
import 'public/public_point_link.dart';
import 'public/public_record_content.dart';
import 'public/public_record_document.dart';
import 'public/public_record_frame.dart';
import 'public/public_record_skeleton.dart';
import 'public/public_record_unavailable.dart';

export 'public/public_record_unavailable.dart' show RecordUnavailable;

class PublicPointPage extends StatefulWidget {
  const PublicPointPage({
    super.key,
    required this.repository,
    required this.token,
    this.simulatedDay,
    this.seed,
    this.onAdvance,
    this.initialTextFirst = false,
    this.isOnline,
    this.connectivity,
    this.clock,
    this.baseUri,
    this.onPrint,
  });
  final PublicPointRepository repository;
  final String token;
  final int? simulatedDay;
  final int? seed;
  final VoidCallback? onAdvance;
  final bool initialTextFirst;
  final bool Function()? isOnline;
  final Stream<bool>? connectivity;
  final DateTime Function()? clock;
  final Uri? baseUri;
  final ValueChanged<String>? onPrint;

  @override
  State<PublicPointPage> createState() => _PublicPointPageState();
}

class _PublicPointPageState extends State<PublicPointPage> {
  late PublicPointController _controller;
  late bool _textFirst;

  @override
  void initState() {
    super.initState();
    _textFirst = widget.initialTextFirst;
    _initialize();
  }

  void _initialize() {
    _controller = PublicPointController(
      repository: widget.repository,
      token: widget.token,
      isOnline: widget.isOnline ?? () => browser.isOnline,
      connectivity: widget.connectivity ?? browser.connectivityChanges,
      clock: widget.clock,
    );
    unawaited(_controller.refresh());
  }

  @override
  void didUpdateWidget(covariant PublicPointPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token ||
        oldWidget.repository != widget.repository) {
      _controller.dispose();
      _initialize();
    }
    if (oldWidget.initialTextFirst != widget.initialTextFirst) {
      _textFirst = widget.initialTextFirst;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Uri get _link => publicPointLink(
    base: widget.baseUri ?? Uri.base,
    token: widget.token,
    seed: widget.seed,
    day: widget.simulatedDay,
    textFirst: _textFirst,
  );

  Future<void> _share() async {
    try {
      await Clipboard.setData(ClipboardData(text: _link.toString()));
      if (mounted) _message('Public record link copied');
    } catch (_) {
      if (mounted) _message('The link could not be copied. Try again.');
    }
  }

  void _print() {
    final document = publicRecordDocument(
      lookup: _controller.lookup!,
      link: _link,
      loadedAt: _controller.loadedAt!,
      isSnapshot: _controller.isSnapshot,
    );
    try {
      (widget.onPrint ?? browser.openPrintDocument)(document);
    } catch (_) {
      _message('The print view could not open. Allow a new tab and try again.');
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _report() async {
    if (!_controller.canReport) return;
    final record = _controller.record!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PublicConcernForm(
        controller: _controller,
        pointLabel: record.pointLabel,
        timezone: record.timezone,
        isSimulated: record.isSimulated,
        sessionOnly: widget.repository is SimulationPublicPointRepository,
        textFirst: _textFirst,
        onReceived: () {
          if (mounted) unawaited(_controller.refresh());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => PublicRecordFrame(
      textFirst: _textFirst,
      onToggleView: () => setState(() => _textFirst = !_textFirst),
      onRefresh: _controller.refreshing ? null : _controller.refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_controller.record?.isSimulated == true ||
              widget.simulatedDay != null) ...[
            const SimulationNotice(),
            const SizedBox(height: 24),
          ],
          if (_controller.phase == PublicPointPhase.loading)
            PublicRecordSkeleton(textFirst: _textFirst)
          else if (_controller.record == null)
            PublicRecordUnavailable(
              phase: _controller.phase,
              status: _controller.lookup?.status,
              textFirst: _textFirst,
              onRetry: _controller.refresh,
            )
          else
            PublicRecordContent(
              controller: _controller,
              textFirst: _textFirst,
              onReport: _report,
              onShare: _share,
              onPrint: _print,
              simulatedDay: widget.simulatedDay,
              seed: widget.seed,
              onAdvance: widget.onAdvance,
            ),
        ],
      ),
    ),
  );
}
