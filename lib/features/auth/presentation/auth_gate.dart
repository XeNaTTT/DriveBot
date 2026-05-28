import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

final class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.controller,
    required this.hudBuilder,
    super.key,
  });

  final AuthController controller;
  final WidgetBuilder hudBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.status == AuthStatus.loggedOut &&
            controller.isSupabaseConfigured) {
          return LoginScreen(controller: controller);
        }

        return Stack(
          children: [
            hudBuilder(context),
            Positioned(
              top: 44,
              right: 16,
              child: SafeArea(
                child: FilledButton.tonalIcon(
                  key: const Key('profile-button'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProfileScreen(controller: controller),
                    ),
                  ),
                  icon: const Icon(Icons.person),
                  label: const Text('Profil'),
                ),
              ),
            ),
            if (!controller.isSupabaseConfigured)
              const Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: _SupabaseFallbackBanner(),
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _SupabaseFallbackBanner extends StatelessWidget {
  const _SupabaseFallbackBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'Supabase ist nicht konfiguriert. Die App läuft im Gastmodus.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
