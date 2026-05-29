import 'package:flutter/material.dart';

import '../application/auth_controller.dart';

final class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

final class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('auth-password-field'),
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Passwort'),
                    ),
                    const SizedBox(height: 16),
                    if (widget.controller.errorMessage != null)
                      _MessageBox(
                        message: widget.controller.errorMessage!,
                        isError: true,
                      ),
                    if (widget.controller.profileWarning != null)
                      _MessageBox(
                        message: widget.controller.profileWarning!,
                        isError: true,
                      ),
                    if (widget.controller.infoMessage != null)
                      _MessageBox(
                        message: widget.controller.infoMessage!,
                        isError: false,
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('auth-sign-in-button'),
                      onPressed: widget.controller.isBusy ? null : _signIn,
                      child: const Text('Anmelden'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('auth-sign-up-button'),
                      onPressed: widget.controller.isBusy ? null : _signUp,
                      child: const Text('Konto erstellen'),
                    ),
                    TextButton(
                      key: const Key('auth-password-reset-button'),
                      onPressed: widget.controller.isBusy
                          ? null
                          : _sendPasswordReset,
                      child: const Text('Passwort vergessen?'),
                    ),
                    const Divider(height: 32),
                    FilledButton.icon(
                      key: const Key('auth-apple-sign-in-button'),
                      onPressed: widget.controller.isBusy
                          ? null
                          : widget.controller.signInWithApple,
                      icon: const Icon(Icons.apple),
                      label: const Text('Mit Apple anmelden'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      key: const Key('auth-continue-guest-button'),
                      onPressed: widget.controller.isBusy
                          ? null
                          : widget.controller.continueAsGuest,
                      child: const Text('Ohne Konto fortfahren'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Gastmodus', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() => widget.controller.signIn(
    email: _emailController.text,
    password: _passwordController.text,
  );

  Future<void> _signUp() => widget.controller.signUp(
    email: _emailController.text,
    password: _passwordController.text,
  );

  Future<void> _sendPasswordReset() =>
      widget.controller.sendPasswordResetEmail(_emailController.text);
}

final class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError
              ? colorScheme.errorContainer
              : colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            style: TextStyle(
              color: isError
                  ? colorScheme.onErrorContainer
                  : colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
