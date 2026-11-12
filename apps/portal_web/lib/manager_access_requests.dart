import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_design_system/design_system.dart';

/// Pending self-service access requests for the selected facility.
/// Visible to organization administrators; decisions go through the
/// review_access_request RPC which re-checks admin authority server-side.
class AccessRequestsPanel extends StatefulWidget {
  const AccessRequestsPanel({
    super.key,
    required this.client,
    required this.facilityId,
    required this.onChanged,
  });
  final SupabaseClient client;
  final String facilityId;
  final VoidCallback onChanged;
  @override
  State<AccessRequestsPanel> createState() => _AccessRequestsPanelState();
}

class _AccessRequestsPanelState extends State<AccessRequestsPanel> {
  List<Map<String, dynamic>> requests = const [];
  bool loading = true;
  String? error;
  final deciding = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AccessRequestsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facilityId != widget.facilityId) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await widget.client
          .from('access_requests')
          .select()
          .eq('facility_id', widget.facilityId)
          .eq('status', 'pending')
          .order('created_at');
      if (mounted) {
        setState(() {
          requests = rows.cast<Map<String, dynamic>>();
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Access requests could not be loaded.';
        });
      }
    }
  }

  Future<void> _decide(String requestId, bool approve, {String? reason}) async {
    setState(() => deciding.add(requestId));
    try {
      final params = <String, dynamic>{
        'p_request_id': requestId,
        'p_approve': approve,
      };
      if (reason != null) params['p_reason'] = reason;
      await widget.client.rpc('review_access_request', params: params);
      await _load();
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The decision could not be recorded. Refresh and retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => deciding.remove(requestId));
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject access request'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed == true && mounted && text.isNotEmpty) {
      await _decide(request['id'] as String, false, reason: text);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error));
    }
    if (requests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('Pending access requests'),
        for (final request in requests)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${request['email']} requests ${request['requested_role']} access',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Approval creates an active membership immediately. Rejection requires a reason and is recorded in the audit trail.',
                    style: TextStyle(color: TankColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: deciding.contains(request['id'])
                            ? null
                            : () => _decide(request['id'] as String, true),
                        child: const Text('Approve'),
                      ),
                      OutlinedButton(
                        onPressed: deciding.contains(request['id'])
                            ? null
                            : () => _reject(request),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
