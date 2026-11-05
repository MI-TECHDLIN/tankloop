import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_localization/localization.dart';
import 'package:uuid/uuid.dart';
import 'public_notice.dart';
import 'public_point_controller.dart';

class PublicConcernForm extends StatefulWidget {
  const PublicConcernForm({
    super.key,
    required this.controller,
    required this.pointLabel,
    required this.timezone,
    required this.isSimulated,
    required this.textFirst,
    required this.onReceived,
    this.sessionOnly = false,
  });
  final PublicPointController controller;
  final String pointLabel;
  final String timezone;
  final bool isSimulated;
  final bool textFirst;
  final bool sessionOnly;
  final VoidCallback onReceived;

  @override
  State<PublicConcernForm> createState() => _PublicConcernFormState();
}

class _PublicConcernFormState extends State<PublicConcernForm> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _contact = TextEditingController();
  ConcernCategory? _category;
  bool _contactConsent = false;
  bool _sending = false;
  PublicRequestFailure? _failure;
  PublicConcernSubmission? _command;
  PublicConcernReceipt? _receipt;

  @override
  void dispose() {
    _description.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending ||
        !widget.controller.canReport ||
        !_form.currentState!.validate()) {
      return;
    }
    var command = PublicConcernSubmission(
      eventId: _command?.eventId ?? const Uuid().v4(),
      token: widget.controller.token,
      category: _category!,
      description: _description.text.trim(),
      contact: _contactConsent ? _contact.text.trim() : null,
      contactConsent: _contactConsent,
    );
    if (_command != null && !_command!.sameContent(command)) {
      command = PublicConcernSubmission(
        eventId: const Uuid().v4(),
        token: command.token,
        category: command.category,
        description: command.description,
        contact: command.contact,
        contactConsent: command.contactConsent,
      );
    }
    _command = command;
    setState(() {
      _sending = true;
      _failure = null;
    });
    try {
      final receipt = await widget.controller.repository
          .submitConcern(command)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() => _receipt = receipt);
      widget.onReceived();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _failure = error is PublicRequestFailure
            ? error
            : const PublicRequestFailure(PublicFailureKind.unavailable),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !_sending,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Report a concern',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close concern form',
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.pointLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (widget.isSimulated) ...[
                  const SimulationNotice(),
                  const SizedBox(height: 16),
                ],
                if (_receipt case final receipt?)
                  Semantics(
                    liveRegion: true,
                    child: PublicNotice(
                      textFirst: widget.textFirst,
                      title: receipt.isSimulated
                          ? 'Simulated concern received'
                          : 'Concern received for review',
                      icon: Icons.receipt_long_outlined,
                      message: [
                        widget.sessionOnly
                            ? 'Demo concern recorded in this session. Closing or reloading the page clears this submission. No facility or external service was contacted.'
                            : 'This receipt confirms database receipt, not a verified finding or external notification.',
                        'Your description and contact details are not published.',
                        'Received ${recordTime(receipt.receivedAt, timezone: widget.timezone)}',
                        'Receipt ${receipt.eventId}',
                      ].join('\n\n'),
                      action: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back to point record'),
                      ),
                    ),
                  )
                else ...[
                  const Text(
                    'Anonymous by default. Describe what you noticed. A resident report is not a verified laboratory finding.',
                  ),
                  const SizedBox(height: 16),
                  if (!widget.controller.online)
                    PublicNotice(
                      textFirst: widget.textFirst,
                      title: 'Offline - concern not sent',
                      message:
                          'Reconnect and refresh the point record to send. Text stays only in this open form; it is not saved on this device or queued for upload.',
                      caution: true,
                      icon: Icons.cloud_off_outlined,
                    )
                  else if (!widget.controller.canReport && !_sending)
                    PublicNotice(
                      textFirst: widget.textFirst,
                      title: 'Refresh the point record first',
                      message:
                          'The record is stale or access has changed. Close this form and refresh before sending a concern.',
                      caution: true,
                      icon: Icons.history_rounded,
                    ),
                  if (_failure case final failure?) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: PublicNotice(
                        textFirst: widget.textFirst,
                        caution: true,
                        title: failure.kind == PublicFailureKind.permission
                            ? 'Public reporting access unavailable'
                            : 'Concern not confirmed',
                        message: switch (failure.kind) {
                          PublicFailureKind.permission =>
                            'Permission denied by the service. Ask the facility manager to check public reporting access. No receipt has been received.',
                          PublicFailureKind.revoked =>
                            'This QR label is no longer active. Close the form and refresh the record. No receipt has been received.',
                          PublicFailureKind.rateLimited =>
                            'Please wait one minute before retrying. This point has received several recent reports. No receipt has been received for this request.',
                          PublicFailureKind.invalid =>
                            'Review the category, description and contact consent before retrying. No receipt has been received.',
                          PublicFailureKind.conflict =>
                            'This receipt identifier belongs to different content. Close this form and review the point before sending a new concern.',
                          PublicFailureKind.unavailable =>
                            'The service did not return a receipt. Your text is only in this open form. Retry unchanged to check the same report without duplicating it.',
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<ConcernCategory>(
                          key: const ValueKey('concern-category'),
                          decoration: const InputDecoration(
                            labelText: 'What did you notice?',
                          ),
                          isExpanded: true,
                          items: [
                            for (final category in ConcernCategory.values)
                              DropdownMenuItem(
                                value: category,
                                child: Text(category.label),
                              ),
                          ],
                          onChanged: _sending
                              ? null
                              : (value) => setState(() => _category = value),
                          validator: (value) => value == null
                              ? 'Choose a concern category.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('concern-description'),
                          controller: _description,
                          enabled: !_sending,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'Describe your concern (private)',
                            helperText:
                                'Do not include someone else’s personal details.',
                            helperMaxLines: 3,
                          ),
                          validator: (value) => (value?.trim().length ?? 0) < 5
                              ? 'Add a description of at least 5 characters.'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _contactConsent,
                          onChanged: _sending
                              ? null
                              : (value) => setState(
                                  () => _contactConsent = value ?? false,
                                ),
                          title: const Text(
                            'Let the facility manager contact me about this concern',
                          ),
                          subtitle: const Text(
                            'Optional. Contact details remain private.',
                          ),
                        ),
                        if (_contactConsent) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('concern-contact'),
                            controller: _contact,
                            enabled: !_sending,
                            maxLength: 320,
                            decoration: const InputDecoration(
                              labelText: 'Email or phone (private)',
                            ),
                            validator: (value) =>
                                (value?.trim().length ?? 0) < 3
                                ? 'Enter contact details or turn off follow-up contact.'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_sending) ...[
                          Semantics(
                            liveRegion: true,
                            label: 'Sending concern. Awaiting a receipt.',
                            child: ExcludeSemantics(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Sending concern. Awaiting a receipt.',
                                  ),
                                  if (!widget.textFirst) ...[
                                    const SizedBox(height: 12),
                                    const FrostedSkeleton(height: 32),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        FilledButton.icon(
                          onPressed:
                              _sending ||
                                  !widget.controller.canReport ||
                                  _failure?.kind == PublicFailureKind.conflict
                              ? null
                              : _send,
                          icon: const Icon(Icons.send_outlined),
                          label: Text(
                            _sending
                                ? 'Awaiting receipt'
                                : _failure != null
                                ? 'Retry concern'
                                : _contactConsent
                                ? 'Send concern'
                                : 'Send anonymous concern',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
