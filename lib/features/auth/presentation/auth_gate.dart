import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

typedef AuthenticatedChildBuilder = Widget Function(
  BuildContext context,
  AuthController controller,
  AuthState state,
);

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.controller,
    required this.builder,
    super.key,
  });

  final AuthController controller;
  final AuthenticatedChildBuilder builder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final state = controller.state;
          if (state.status == AuthStatus.loading) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          if (state.showsHud) return builder(context, controller, state);

          return LoginScreen(controller: controller);
        },
      );
}

class AccountEntryButton extends StatelessWidget {
  const AccountEntryButton({required this.controller, super.key});

  final AuthController controller;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Nutzerkonto',
        button: true,
        child: IconButton.filledTonal(
          key: const Key('account-entry-button'),
          tooltip: 'Profil',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(controller: controller),
            ),
          ),
          icon: const Icon(Icons.account_circle),
        ),
      );
}
