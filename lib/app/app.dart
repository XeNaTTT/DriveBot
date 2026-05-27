import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/data_sources/data/mock_data_source_registry.dart';
import '../features/hud/data/mock_hud_repository.dart';
import '../features/hud/presentation/hud_screen.dart';
import '../features/location/data/ios_location_runtime.dart';
import '../features/location/data/mock_location_repository.dart';
import '../features/location/data/mock_permission_repository.dart';
import '../features/location/domain/permission_repository.dart';
import '../shared/theme/app_theme.dart';

class DriveAssistantApp extends StatelessWidget {
  const DriveAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final useRealSensors = defaultTargetPlatform == TargetPlatform.iOS;
    final locationRepository =
        useRealSensors ? IosLocationRuntime() : MockLocationRepository();
    final permissionRepository = useRealSensors
        ? locationRepository as PermissionRepository
        : MockPermissionRepository();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DriveAssistant AR',
      theme: buildAppTheme(),
      home: HudScreen(
        hudRepository: MockHudRepository(),
        locationRepository: locationRepository,
        dataSourceRegistry: MockDataSourceRegistry(),
        permissionRepository: permissionRepository,
      ),
    );
  }
}
