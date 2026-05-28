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
                    style: Theme.of(context).textTheme.headlineSmall,
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
                  if (controller.status == AuthStatus.loggedIn)
                    FilledButton(
                      key: const Key('sign-out-button'),
                      onPressed: controller.isBusy ? null : controller.signOut,
                      child: const Text('Abmelden'),
                    ),
                  TextButton(
                    key: const Key('back-to-app-button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Zurück zur App'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
