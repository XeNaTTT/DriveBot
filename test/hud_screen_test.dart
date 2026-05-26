import 'package:driveassistant_ar/features/data_sources/domain/data_source_registry.dart';
import 'package:driveassistant_ar/features/data_sources/domain/data_source_status.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_repository.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/hud/presentation/hud_screen.dart';
import 'package:driveassistant_ar/features/location/domain/location_repository.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:driveassistant_ar/features/location/domain/permission_repository.dart';
import 'package:driveassistant_ar/features/location/domain/sensor_permission_status.dart';
import 'package:driveassistant_ar/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHud({
    required List<HudWarningItem> warnings,
    SensorPermissionStatus permissions = const SensorPermissionStatus(
      camera: SensorPermissionState.denied,
      location: SensorPermissionState.denied,
      motion: SensorPermissionState.denied,
    ),
    Size size = const Size(390, 844),
    double textScaleFactor = 1,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: MaterialApp(
        theme: buildAppTheme(),
        home: HudScreen(
          hudRepository: _FakeHudRepository(warnings),
          locationRepository: const _FakeLocationRepository(),
          dataSourceRegistry: const _FakeDataSourceRegistry(),
          permissionRepository: _FakePermissionRepository(permissions),
        ),
      ),
    );
  }

  testWidgets('compact device renders without overflow', (tester) async {
    await tester.pumpWidget(
      buildHud(warnings: _sampleWarnings, size: const Size(320, 568)),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('hud-root')), findsOneWidget);
  });

  testWidgets(
    'normal device and large text scale render without overflow',
    (tester) async {
      await tester.pumpWidget(
        buildHud(warnings: _sampleWarnings, textScaleFactor: 1.5),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('primary-warning-title')), findsOneWidget);
    },
  );

  testWidgets('primary and warning card are found by keys', (tester) async {
    await tester.pumpWidget(buildHud(warnings: _sampleWarnings));
    expect(find.byKey(const Key('primary-warning-title')), findsOneWidget);
    expect(find.byKey(const Key('warning-card-speedCamera')), findsOneWidget);
  });

  testWidgets('empty state is shown for no warnings', (tester) async {
    await tester.pumpWidget(buildHud(warnings: const []));
    expect(find.byKey(const Key('empty-warning-state')), findsOneWidget);
  });

  testWidgets('permission denied fallback is shown', (tester) async {
    await tester.pumpWidget(buildHud(warnings: _sampleWarnings));
    expect(find.byKey(const Key('permission-fallback')), findsOneWidget);
  });

  testWidgets('tap warning card keeps it present and interactive',
      (tester) async {
    await tester.pumpWidget(buildHud(warnings: _sampleWarnings));
    await tester.tap(find.byKey(const Key('warning-card-speedCamera')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('warning-card-speedCamera')), findsOneWidget);
  });
}

const _sampleWarnings = [
  HudWarningItem(
    type: WarningType.speedCamera,
    title: 'Speed Camera Ahead',
    detail: 'Fixed camera in 450 m',
    distanceMeters: 450,
    bearingDegrees: 75,
    severity: 4,
  ),
  HudWarningItem(
    type: WarningType.speedLimit,
    title: 'Speed Limit 80 km/h',
    detail: 'Zone starts in 300 m',
    distanceMeters: 300,
    bearingDegrees: 55,
    severity: 5,
  ),
];

class _FakeHudRepository implements HudRepository {
  const _FakeHudRepository(this.warnings);
  final List<HudWarningItem> warnings;
  @override
  List<HudWarningItem> getNearbyWarnings() => warnings;
}

class _FakePermissionRepository implements PermissionRepository {
  _FakePermissionRepository(this.permissions);
  final SensorPermissionStatus permissions;

  @override
  ValueListenable<SensorPermissionStatus> get permissionStatusListenable =>
      ValueNotifier(permissions);
}

class _FakeLocationRepository implements LocationRepository {
  const _FakeLocationRepository();

  @override
  ValueListenable<LocationStatus> get locationStatusListenable => _status;

  static final ValueNotifier<LocationStatus> _status = ValueNotifier(
    const LocationStatus(
      speedKph: 84,
      headingDegrees: 58,
      gpsFixStatus: GpsFixStatus.strong,
      isMock: true,
      isSpeedEstimatedFromGps: false,
    ),
  );
}

class _FakeDataSourceRegistry implements DataSourceRegistry {
  const _FakeDataSourceRegistry();
  @override
  List<DataSourceStatus> getRegisteredSources() => const [];
}
