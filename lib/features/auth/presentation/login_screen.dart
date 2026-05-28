import 'package:flutter/material.dart';

import '../application/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nutzerkonto',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('Nicht angemeldet', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('auth-email-field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-Mail'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('auth-password-field'),
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Passwort'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('auth-sign-in-button'),
                      onPressed: _busy
                          ? null
                          : () => _submit(() => widget.controller.signIn(
                                email: _emailController.text,
                                password: _passwordController.text,
                              )),
                      child: const Text('Anmelden'),
                    ),
                    OutlinedButton(
                      key: const Key('auth-sign-up-button'),
                      onPressed: _busy
                          ? null
                          : () => _submit(() => widget.controller.signUp(
                                email: _emailController.text,
                                password: _passwordController.text,
                              )),
                      child: const Text('Konto erstellen'),
                    ),
                    TextButton(
                      key: const Key('auth-password-reset-button'),
                      onPressed: _busy
                          ? null
                          : () => _submit(() => widget.controller
                              .sendPasswordResetEmail(_emailController.text)),
                      child: const Text('Passwort vergessen?'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('auth-continue-guest-button'),
                      onPressed: _busy
                          ? null
                          : () => _submit(widget.controller.continueAsGuest),
                      child: const Text('Ohne Konto fortfahren'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Gastmodus', textAlign: TextAlign.center),
                    AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, _) {
                        final message = widget.controller.state.message;
                        if (message == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(message, textAlign: TextAlign.center),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
