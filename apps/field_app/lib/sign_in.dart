import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:url_launcher/url_launcher.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.portalBaseUrl = 'http://localhost:8081'});
  final String portalBaseUrl;
  @override
  State<SignInScreen> createState() => SignInScreenState();
}

class SignInScreenState extends State<SignInScreen> {
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

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on AuthException {
      if (mounted) {
        setState(
          () => error =
              'Sign-in could not be completed. Check your credentials and active invitation.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not reach the sign-in service. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openSignup() async {
    final url =
        '${widget.portalBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/#/signup';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not open the account page. Visit $url in your browser.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => TankBackdrop(
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: TankColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: TankColors.navy.withValues(alpha: .08),
                      offset: const Offset(0, 16),
                      blurRadius: 40,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LayeredRecordArt(
                        accent: TankAccents.inspection,
                        label: 'FIELD RECORD',
                        height: 170,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const TankBrand(
                              surface: 'FIELD',
                              showSimulationBadge: false,
                            ),
                            const SizedBox(height: 24),
                            const TwoToneHeading('Keep the loop\n', 'moving.'),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in with your assigned facility account.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: TankColors.muted),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: password,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              onSubmitted: (_) {
                                if (!busy) unawaited(submit());
                              },
                            ),
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    color: TankColors.amber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: busy ? null : submit,
                              child: Text(busy ? 'Signing in…' : 'Sign in'),
                            ),
                            TextButton(
                              onPressed: busy ? null : _openSignup,
                              child: const Text(
                                'New to TankLoop? Create an account',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
