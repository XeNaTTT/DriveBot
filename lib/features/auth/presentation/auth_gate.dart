import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

typedef AuthenticatedChildBuilder =
    Widget Function(BuildContext context, AuthController controller);

final class AuthGate extends StatelessWidget {
  const AuthGate({required this.controller, required this.builder, super.key});

  final AuthController controller;
  final AuthenticatedChildBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.status == AuthStatus.loggedOut &&
            controller.isSupabaseConfigured) {
          return LoginScreen(controller: controller);
        }

        return builder(context, controller);
      },
    );
  }
}

final class AccountEntryButton extends StatelessWidget {
  const AccountEntryButton({required this.controller, super.key});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountMenuAction>(
      key: const Key('account-entry-button'),
      tooltip: 'Nutzerkonto',
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _AccountMenuAction.openProfile:
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(controller: controller),
              ),
            );
        }
      },
      itemBuilder: (context) => [
        if (!controller.isSupabaseConfigured)
          const PopupMenuItem<_AccountMenuAction>(
            enabled: false,
            child: _SupabaseFallbackMenuNotice(),
          ),
        if (!controller.isSupabaseConfigured) const PopupMenuDivider(),
        const PopupMenuItem<_AccountMenuAction>(
          value: _AccountMenuAction.openProfile,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_circle),
            title: Text('Profil öffnen'),
          ),
        ),
      ],
      child: Semantics(
        label: 'Nutzerkonto',
        button: true,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.account_circle),
          ),
        ),
      ),
    );
  }
}

enum _AccountMenuAction { openProfile }

final class _SupabaseFallbackMenuNotice extends StatelessWidget {
  const _SupabaseFallbackMenuNotice();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.info_outline),
        title: Text(
          'Supabase nicht konfiguriert',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('Die App läuft im Gastmodus.'),
      ),
    );
  }
}
