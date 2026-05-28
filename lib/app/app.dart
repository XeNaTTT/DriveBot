import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/guest_auth_repository.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/auth/domain/app_user.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/data_sources/data/mock_data_source_registry.dart';
import '../features/hud/presentation/hud_screen.dart';
import '../features/location/data/ios_location_runtime.dart';
import '../features/location/data/mock_location_repository.dart';
import '../features/location/data/mock_permission_repository.dart';
import '../features/location/domain/permission_repository.dart';
import '../features/traffic/data/autobahn_warning_repository.dart';
import '../features/warnings/data/composite_warning_repository.dart';
import '../features/warnings/data/merged_warning_repository.dart';
import '../features/warnings/data/warning_cache.dart';
import '../features/weather/data/open_meteo_warning_repository.dart';
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
    final useRealSensors = defaultTargetPlatform == TargetPlatform.iOS;
    final locationRepository =
        useRealSensors ? IosLocationRuntime() : MockLocationRepository();
    final permissionRepository = useRealSensors
        ? locationRepository as PermissionRepository
        : MockPermissionRepository();
    final warningRepository = CompositeWarningRepository(
      primary: MergedWarningRepository(
        [
          OpenMeteoWarningRepository.live(cache: InMemoryWarningCache()),
          AutobahnWarningRepository.live(cache: InMemoryWarningCache()),
        ],
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DriveAssistant AR',
      theme: buildAppTheme(),
      home: AuthGate(
        controller: _authController,
        builder: (context, controller) => HudScreen(
          hudRepository: warningRepository,
          locationRepository: locationRepository,
          dataSourceRegistry: MockDataSourceRegistry(),
          permissionRepository: permissionRepository,
          accountEntryPoint: AccountEntryButton(controller: controller),
        ),
      ),
    );
  }
}
