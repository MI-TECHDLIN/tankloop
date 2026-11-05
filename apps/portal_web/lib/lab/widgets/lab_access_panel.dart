import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'lab_form_support.dart';

class LabAccessPanel extends StatefulWidget {
  const LabAccessPanel({
    super.key,
    required this.client,
    required this.onSignedIn,
  });
  final SupabaseClient client;
  final VoidCallback onSignedIn;
  @override
  State<LabAccessPanel> createState() => _LabAccessPanelState();
}

class _LabAccessPanelState extends State<LabAccessPanel> {
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
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
      if (mounted) widget.onSignedIn();
    } on AuthException {
      if (mounted) {
        setState(
          () => error =
              'Sign-in was not accepted. Check the account details and your laboratory invitation.',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign in to TankLoop Lab',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the account assigned to your laboratory facility. Your server-side membership determines access.',
            style: TextStyle(color: TankColors.muted),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: email,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: labRequired,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: password,
            enabled: !busy,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            validator: labRequired,
            onFieldSubmitted: (_) => busy ? null : signIn(),
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
  );
}
