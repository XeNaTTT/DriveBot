import 'package:flutter/material.dart';

import '../application/auth_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final state = controller.state;
              final user = state.user;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Nutzerkonto',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user == null
                                ? 'Nicht angemeldet'
                                : 'Eingeloggt als',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(user?.email ?? 'Gastmodus'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: true,
                    onChanged: null,
                    title: const Text('Live-Daten verwenden'),
                    subtitle: const Text('Basiseinstellung für Fahrhinweise'),
                  ),
                  SwitchListTile(
                    value: false,
                    onChanged: null,
                    title: const Text('Debug-Quellen anzeigen'),
                    subtitle: const Text('Nur für Diagnose und Testfahrten'),
                  ),
                  const SizedBox(height: 12),
                  if (user != null)
                    FilledButton.icon(
                      key: const Key('profile-sign-out-button'),
                      onPressed: controller.signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Abmelden'),
                    )
                  else
                    FilledButton.icon(
                      key: const Key('profile-sign-out-button'),
                      onPressed: () {
                        controller.returnToLogin();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Anmelden'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Zurück zur App'),
                  ),
                ],
              );
            },
          ),
        ),
      );
}
