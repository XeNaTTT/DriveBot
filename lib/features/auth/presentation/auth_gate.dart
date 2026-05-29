import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({required this.controller, required this.child, super.key});

  final AuthController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final state = controller.state;
          if (state.status == AuthStatus.loading) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (state.status == AuthStatus.loggedOut) {
            return LoginScreen(controller: controller);
          }
          return _AuthenticatedShell(controller: controller, child: child);
        },
      );
}

class _AuthenticatedShell extends StatelessWidget {
  const _AuthenticatedShell({required this.controller, required this.child});

  final AuthController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return Stack(
      children: [
        child,
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 54, right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (state.isGuest)
                    Container(
                      key: const Key('guest-mode-pill'),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x99FFA94D)),
                      ),
                      child: const Text('Gastmodus'),
                    ),
                  FloatingActionButton.small(
                    key: const Key('profile-entry-button'),
                    heroTag: 'profile-entry',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileScreen(controller: controller),
                      ),
                    ),
                    child: const Icon(Icons.person_outline),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
