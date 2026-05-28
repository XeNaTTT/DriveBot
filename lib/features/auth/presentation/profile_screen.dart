import 'package:flutter/material.dart';

import '../application/auth_controller.dart';

final class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final user = controller.user;
            final statusText = switch (controller.status) {
              AuthStatus.loggedIn =>
                'Eingeloggt als ${user?.email ?? user?.id}',
              AuthStatus.guest => 'Gastmodus',
              AuthStatus.loggedOut => 'Nicht angemeldet',
            };

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Nutzerkonto',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    statusText,
                    key: const Key('profile-status'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (controller.profileWarning != null) ...[
                    const SizedBox(height: 12),
                    Text(controller.profileWarning!),
                  ],
                  const Spacer(),
                  OutlinedButton(
                    key: const Key('profile-back-button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Zurück zur App'),
                  ),
                  if (controller.status == AuthStatus.loggedIn) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('profile-sign-out-button'),
                      onPressed: controller.isBusy
                          ? null
                          : () async {
                              await controller.signOut();
                              if (context.mounted) {
                                Navigator.of(context).maybePop();
                              }
                            },
                      child: const Text('Abmelden'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('profile-reset-button'),
                      onPressed: user?.email == null || controller.isBusy
                          ? null
                          : () =>
                              controller.sendPasswordResetEmail(user!.email!),
                      child: const Text('Passwort zurücksetzen'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
