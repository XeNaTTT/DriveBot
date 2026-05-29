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
  String? _validationError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool createAccount}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_isValidEmail(email)) {
      setState(() =>
          _validationError = 'Bitte gib eine gültige E-Mail-Adresse ein.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _validationError = 'Bitte gib ein Passwort ein.');
      return;
    }

    setState(() => _validationError = null);
    if (createAccount) {
      await widget.controller.signUp(email: email, password: password);
    } else {
      await widget.controller.signIn(email: email, password: password);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() =>
          _validationError = 'Bitte gib eine gültige E-Mail-Adresse ein.');
      return;
    }
    setState(() => _validationError = null);
    await widget.controller.sendPasswordResetEmail(email);
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final state = widget.controller.state;
              final isLoading = state.status == AuthStatus.loading;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 72),
                        const SizedBox(height: 16),
                        Text(
                          'Nutzerkonto',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          key: const Key('auth-email-field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration:
                              const InputDecoration(labelText: 'E-Mail'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('auth-password-field'),
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration:
                              const InputDecoration(labelText: 'Passwort'),
                        ),
                        const SizedBox(height: 12),
                        if (_validationError != null || state.error != null)
                          _AuthMessage(
                            text: _validationError ?? state.error!,
                            isError: true,
                          ),
                        if (state.message != null)
                          _AuthMessage(text: state.message!, isError: false),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const Key('auth-login-button'),
                          onPressed: isLoading
                              ? null
                              : () => _submit(createAccount: false),
                          child: const Text('Anmelden'),
                        ),
                        OutlinedButton(
                          key: const Key('auth-signup-button'),
                          onPressed: isLoading
                              ? null
                              : () => _submit(createAccount: true),
                          child: const Text('Konto erstellen'),
                        ),
                        TextButton(
                          key: const Key('auth-reset-password-button'),
                          onPressed: isLoading ? null : _resetPassword,
                          child: const Text('Passwort vergessen?'),
                        ),
                        const Divider(height: 28),
                        TextButton.icon(
                          key: const Key('continue-as-guest-button'),
                          onPressed: isLoading
                              ? null
                              : widget.controller.continueAsGuest,
                          icon: const Icon(Icons.directions_car_outlined),
                          label: const Text('Ohne Konto fortfahren'),
                        ),
                        if (isLoading) ...[
                          const SizedBox(height: 16),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? Theme.of(context).colorScheme.error : null,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
