import 'package:flutter/material.dart';

import '../application/auth_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final state = controller.state;
          final user = state.user;
          final isGuest = user?.isGuest ?? false;
          final email = user?.email;

          return Scaffold(
            appBar: AppBar(title: const Text('Profil')),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nutzerkonto',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(isGuest ? 'Gastmodus' : 'Eingeloggt als'),
                    const SizedBox(height: 8),
                    Text(email ?? 'Nicht angemeldet'),
                    const Spacer(),
                    OutlinedButton(
                      key: const Key('profile-back-button'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Zurück zur App'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('profile-sign-out-button'),
                      onPressed: () async {
                        await controller.signOut();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: const Text('Abmelden'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('profile-reset-button'),
                      onPressed: email == null
                          ? null
                          : () => controller.sendPasswordResetEmail(email),
                      child: const Text('Passwort zurücksetzen'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
