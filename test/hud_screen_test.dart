import 'package:driveassistant_ar/features/camera/data/camera_runtime_service.dart';
import 'package:driveassistant_ar/features/camera/presentation/camera_hud_background.dart';
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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHud(
          {required List<HudWarningItem> warnings,
          Size size = const Size(390, 844),
          double textScaleFactor = 1}) =>
      MediaQuery(
        data: MediaQueryData(
            size: size, textScaler: TextScaler.linear(textScaleFactor)),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: HudScreen(
            hudRepository: _FakeHudRepository(warnings),
            locationRepository: const _FakeLocationRepository(),
            dataSourceRegistry: const _FakeDataSourceRegistry(),
            permissionRepository: _FakePermissionRepository(
                const SensorPermissionStatus(
                    camera: SensorPermissionState.denied,
                    location: SensorPermissionState.denied,
                    motion: SensorPermissionState.denied)),
          ),
        ),
      );

  testWidgets('compact iPhone layout renders without RenderFlex overflow',
      (tester) async {
    await tester.pumpWidget(
        buildHud(warnings: _sampleWarnings, size: const Size(320, 568)));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('hud-root')), findsOneWidget);
  });

  testWidgets('large text scale still renders', (tester) async {
    await tester
        .pumpWidget(buildHud(warnings: _sampleWarnings, textScaleFactor: 1.6));
    expect(find.byKey(const Key('primary-warning-card')), findsOneWidget);
  });

  testWidgets('only one bottom warning card is rendered', (tester) async {
    await tester.pumpWidget(buildHud(warnings: _sampleWarnings));
    expect(find.byKey(const Key('primary-warning-card')), findsOneWidget);
  });

  testWidgets('no long warning list is rendered in AR mode', (tester) async {
    await tester.pumpWidget(buildHud(warnings: _sampleWarnings));
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('fallback mode still renders German guidance', (tester) async {
    await tester.pumpWidget(buildHud(warnings: _sampleWarnings));
    expect(find.byKey(const Key('permission-fallback')), findsOneWidget);
    expect(find.textContaining('Fallback aktiv'), findsOneWidget);
  });

  testWidgets('key HUD labels are German', (tester) async {
    await tester.pumpWidget(buildHud(warnings: _sampleWarnings));

    expect(find.textContaining('Tempo'), findsOneWidget);
    expect(find.textContaining('Richtung'), findsOneWidget);
    expect(find.textContaining('Modus'), findsOneWidget);
  });

  testWidgets('debug source indicator marks mock HUD data as fallback',
      (tester) async {
    await tester.pumpWidget(buildHud(warnings: _sampleWarnings));

    expect(find.byKey(const Key('debug-source-indicator')), findsOneWidget);
    expect(find.text('Kamera: Fallback'), findsOneWidget);
    expect(find.text('Standort: Fallback'), findsOneWidget);
    expect(find.text('Warnungen: Mock'), findsOneWidget);
    expect(find.text('Quelle: Fallback-Daten'), findsOneWidget);
  });

  testWidgets('camera unavailable falls back to mock background',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: CameraHudBackground(
            permissionStatus: SensorPermissionStatus(
                camera: SensorPermissionState.granted,
                location: SensorPermissionState.granted,
                motion: SensorPermissionState.unavailable),
            cameraRuntimeService:
                CameraRuntimeService(loadCameraDescriptions: _loadNoCameras))));
    await tester.pump();
    expect(find.byKey(const Key('mock-background-layer')), findsOneWidget);
  });
}

Future<List<Never>> _loadNoCameras() async => const [];

const _sampleWarnings = [
  HudWarningItem(
      type: WarningType.speedCamera,
      title: 'A3 Suben',
      detail: 'Reduce speed',
      distanceMeters: 450,
      bearingDegrees: 58,
      severity: 4),
  HudWarningItem(
      type: WarningType.speedLimit,
      title: '80 km/h',
      detail: 'Zone starts',
      distanceMeters: 300,
      bearingDegrees: 80,
      severity: 5),
  HudWarningItem(
      type: WarningType.roadwork,
      title: 'Roadwork',
      detail: 'Lane merge',
      distanceMeters: 900,
      bearingDegrees: 120,
      severity: 3),
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
          gpsFixStatus: GpsFixStatus.unavailable,
          isMock: true,
          isSpeedEstimatedFromGps: false));
}

class _FakeDataSourceRegistry implements DataSourceRegistry {
  const _FakeDataSourceRegistry();
  @override
  List<DataSourceStatus> getRegisteredSources() => const [];
}
