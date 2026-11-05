import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'manager_controller.dart';
import 'manager_shell.dart';
import 'manager_widgets.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({
    super.key,
    required this.repository,
    this.authClient,
  });
  final ManagerWorkspaceRepository repository;
  final SupabaseClient? authClient;
  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  late ManagerController controller;
  StreamSubscription<AuthState>? authSubscription;
  String? userId;
  int selected = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    controller = ManagerController(widget.repository);
    userId = widget.authClient?.auth.currentUser?.id;
    authSubscription = widget.authClient?.auth.onAuthStateChange.listen((
      event,
    ) {
      if (!mounted) return;
      final nextId = event.session?.user.id;
      if (nextId == userId) return;
      userId = nextId;
      // A dialog can contain private record details as well as the screen.
      Navigator.of(context).popUntil((route) => route is! PopupRoute);
      controller.sessionChanged();
      if (nextId != null) unawaited(controller.refresh());
    });
    unawaited(controller.refresh());
  }

  @override
  void didUpdateWidget(covariant ManagerDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.authClient != widget.authClient) {
      authSubscription?.cancel();
      controller.dispose();
      _connect();
    }
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> signOut() async {
    controller.sessionChanged();
    try {
      await widget.authClient!.auth.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sign-out could not be completed. Reconnect and retry.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => TankBackdrop(
    child: Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ManagerShell(
          controller: controller,
          selected: selected,
          onSelected: (value) => setState(() => selected = value),
          accountAction: widget.authClient?.auth.currentUser == null
              ? null
              : TextButton(
                  onPressed: controller.busy ? null : signOut,
                  child: const Text('Sign out'),
                ),
          accessPanel:
              controller.phase != ManagerViewState.denied ||
                  widget.authClient == null
              ? null
              : widget.authClient!.auth.currentUser == null
              ? _ManagerSignIn(client: widget.authClient!)
              : const NoticeCard(
                  title: 'Manager assignment required',
                  message:
                      'Ask the organization administrator for an active manager or administrator membership. Refresh after it is assigned, or sign out to use a different account.',
                ),
        ),
      ),
    ),
  );
}

class _ManagerSignIn extends StatefulWidget {
  const _ManagerSignIn({required this.client});
  final SupabaseClient client;
  @override
  State<_ManagerSignIn> createState() => _ManagerSignInState();
}

class _ManagerSignInState extends State<_ManagerSignIn> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on AuthException {
      if (mounted) {
        setState(
          () => error =
              'Sign-in was not accepted. Check your account details and manager assignment.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'The sign-in service could not be reached. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Form(
      key: form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign in to TankLoop Manage',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Use your assigned account. Server-side membership determines which facilities you can manage.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: managerRequired,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: password,
              enabled: !busy,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
              validator: managerRequired,
              onFieldSubmitted: (_) => signIn(),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : signIn,
              child: Text(busy ? 'Signing in...' : 'Sign in'),
            ),
          ],
        ),
      ),
    ),
  );
}
