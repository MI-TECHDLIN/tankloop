import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_design_system/design_system.dart';

class AccessSignupScreen extends StatefulWidget {
  const AccessSignupScreen({super.key, this.client});
  final SupabaseClient? client;
  @override
  State<AccessSignupScreen> createState() => _AccessSignupScreenState();
}

class _AccessSignupScreenState extends State<AccessSignupScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  List<Map<String, dynamic>> facilities = const [];
  List<Map<String, dynamic>> myRequests = const [];
  String? facilityId;
  String role = 'field';
  bool busy = false;
  bool loading = true;
  String? error;
  String? notice;

  SupabaseClient? get client => widget.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = client;
    if (c == null) {
      setState(() => loading = false);
      return;
    }
    try {
      if (c.auth.currentUser != null) {
        final joinable = await c.rpc('list_joinable_facilities');
        final requests = await c
            .from('access_requests')
            .select()
            .order('created_at', ascending: false);
        if (!mounted) return;
        setState(() {
          facilities = (joinable as List).cast<Map<String, dynamic>>();
          myRequests = requests.cast<Map<String, dynamic>>();
          facilityId ??= facilities.isEmpty ? null : facilities.first['facility_id'] as String?;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load access options. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signUp() async {
    final c = client;
    if (c == null || busy) return;
    if (password.text != confirm.text) {
      setState(() => error = 'Passwords do not match.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final response = await c.auth.signUp(
        email: email.text.trim(),
        password: password.text,
      );
      if (!mounted) return;
      if (response.session == null) {
        setState(() {
          notice = 'Account created. Check your email to confirm it, then sign in to request facility access.';
        });
      } else {
        setState(() => notice = 'Account created. Choose a facility below to request access.');
        await _load();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => error = e.message.isEmpty ? 'Sign-up was not accepted. Check the email and password.' : e.message);
      }
    } catch (_) {
      if (mounted) setState(() => error = 'The sign-up service could not be reached. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _signIn() async {
    final c = client;
    if (c == null || busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await c.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      if (mounted) await _load();
    } on AuthException {
      if (mounted) setState(() => error = 'Sign-in was not accepted. Check your credentials.');
    } catch (_) {
      if (mounted) setState(() => error = 'The sign-in service could not be reached. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _request() async {
    final c = client;
    if (c == null || busy || facilityId == null) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await c.rpc('request_access', params: {'p_facility_id': facilityId, 'p_role': role});
      if (mounted) {
        setState(() => notice = 'Request sent. An organization administrator will review it.');
        await _load();
      }
    } catch (_) {
      if (mounted) setState(() => error = 'The request could not be submitted. You may already have a pending request for this role.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _statusLabel(String status) => switch (status) {
    'approved' => 'Approved - access is active',
    'rejected' => 'Not approved',
    _ => 'Awaiting administrator review',
  };

  @override
  Widget build(BuildContext context) {
    final c = client;
    if (c == null) {
      return const GlassCard(
        child: NoticeCard(
          title: 'Account access unavailable',
          message: 'Account sign-up requires the connected TankLoop service.',
        ),
      );
    }
    final signedIn = c.auth.currentUser != null;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            signedIn ? 'Request facility access' : 'Create your TankLoop account',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            signedIn
                ? 'Signed in as ${c.auth.currentUser!.email ?? 'your account'}. Request access to a facility; an administrator approves it before you can work.'
                : 'Create an account, then request access to a facility. Access starts after an administrator approves your request.',
            style: const TextStyle(color: TankColors.muted),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (!signedIn) ...[
              const SizedBox(height: 20),
              TextField(
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                enabled: !busy,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirm,
                enabled: !busy,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Confirm password'),
                onSubmitted: (_) => busy ? null : _signUp(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : _signUp,
                child: Text(busy ? 'Working…' : 'Create account'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy ? null : _signIn,
                child: const Text('Already have an account? Sign in'),
              ),
            ],
            if (signedIn && facilities.isNotEmpty) ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: facilityId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Facility'),
                items: [
                  for (final f in facilities)
                    DropdownMenuItem(
                      value: f['facility_id'] as String,
                      child: Text(
                        '${f['organization']} - ${f['label']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy ? null : (value) => setState(() => facilityId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Requested role'),
                items: const [
                  DropdownMenuItem(value: 'field', child: Text('Field - inspections and sampling')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager - incidents and work orders')),
                  DropdownMenuItem(value: 'lab', child: Text('Laboratory - sample review')),
                ],
                onChanged: busy ? null : (value) => setState(() => role = value ?? 'field'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy || facilityId == null ? null : _request,
                child: Text(busy ? 'Sending…' : 'Request access'),
              ),
            ],
            if (signedIn && facilities.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('No facilities are currently open for self-service access. Ask your organization administrator for an invitation.'),
              ),
            if (myRequests.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Your access requests', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final request in myRequests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${request['requested_role']} - ${_statusLabel(request['status'] as String)}',
                    style: const TextStyle(color: TankColors.muted),
                  ),
                ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(notice!, style: const TextStyle(color: TankColors.muted)),
              ),
          ],
        ],
      ),
    );
  }
}
