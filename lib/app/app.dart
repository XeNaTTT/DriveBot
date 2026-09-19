import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/guest_auth_repository.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/auth/domain/app_user.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/ar_racing/application/motion_steering_service.dart';
import '../features/ar_racing/presentation/ar_racing_screen.dart';
import '../shared/theme/app_theme.dart';

class DriveAssistantApp extends StatefulWidget {
  const DriveAssistantApp({
    required this.supabaseConfigured,
    this.authRepository,
    super.key,
  });

  final bool supabaseConfigured;
  final AuthRepository? authRepository;

  @override
  State<DriveAssistantApp> createState() => _DriveAssistantAppState();
}

class _DriveAssistantAppState extends State<DriveAssistantApp> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = AuthController(
      repository: widget.authRepository ?? _buildAuthRepository(),
      isSupabaseConfigured: widget.supabaseConfigured,
    );
  }

  AuthRepository _buildAuthRepository() {
    if (widget.supabaseConfigured) {
      return SupabaseAuthRepository(Supabase.instance.client);
    }
    return GuestAuthRepository(initialUser: const AppUser.guest());
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useRealSensors =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Room Rally AR',
      theme: buildAppTheme(),
      home: AuthGate(
        controller: _authController,
        builder: (context, controller) => ArRacingScreen(
          motionService: useRealSensors
              ? PhoneMotionSteeringService()
              : const MockMotionSteeringService(),
          accountEntryPoint: AccountEntryButton(controller: controller),
        ),
      ),
    );
  }
}
