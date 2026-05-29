import 'package:driveassistant_ar/features/data_sources/domain/data_source_registry.dart';
import 'package:driveassistant_ar/features/data_sources/domain/data_source_status.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_repository.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/hud/presentation/hud_screen.dart';
import 'package:driveassistant_ar/features/location/domain/location_repository.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:driveassistant_ar/features/location/domain/permission_repository.dart';
import 'package:driveassistant_ar/features/location/domain/sensor_permission_status.dart';
import 'package:driveassistant_ar/features/reports/application/speed_camera_report_controller.dart';
import 'package:driveassistant_ar/features/reports/data/composite_speed_camera_report_repository.dart';
import 'package:driveassistant_ar/features/reports/data/local_speed_camera_report_repository.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report_repository.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report_sync_status.dart';
import 'package:driveassistant_ar/shared/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Blitzer melden button renders', (tester) async {
    await tester.pumpWidget(_buildHud(loggedIn: false));
    expect(find.text('Blitzer melden'), findsOneWidget);
  });

  testWidgets('First tap opens type choices', (tester) async {
    await tester.pumpWidget(_buildHud(loggedIn: false));
    await tester.tap(find.text('Blitzer melden'));
    await tester.pump();
    expect(
      find.byKey(const Key('speed-camera-report-choices')),
      findsOneWidget,
    );
  });

  testWidgets('Mobiler Blitzer option exists', (tester) async {
    await tester.pumpWidget(_buildHud(loggedIn: false));
    await tester.tap(find.text('Blitzer melden'));
    await tester.pump();
    expect(find.text('Mobiler Blitzer'), findsOneWidget);
  });

  testWidgets('Fester Blitzer option exists', (tester) async {
    await tester.pumpWidget(_buildHud(loggedIn: false));
    await tester.tap(find.text('Blitzer melden'));
    await tester.pump();
    expect(find.text('Fester Blitzer'), findsOneWidget);
  });

  testWidgets('Second tap creates mobile report', (tester) async {
    final remote = _FakeRemoteRepository();
    await tester.pumpWidget(_buildHud(loggedIn: true, remote: remote));
    await tester.tap(find.text('Blitzer melden'));
    await tester.pump();
    await tester.tap(find.text('Mobiler Blitzer'));
    await tester.pump();
    expect(remote.uploaded.single.type.germanLabel, 'Mobiler Blitzer');
  });

  testWidgets('Second tap creates fixed report', (tester) async {
    final remote = _FakeRemoteRepository();
    await tester.pumpWidget(_buildHud(loggedIn: true, remote: remote));
    await tester.tap(find.text('Blitzer melden'));
    await tester.pump();
    await tester.tap(find.text('Fester Blitzer'));
    await tester.pump();
    expect(remote.uploaded.single.type.germanLabel, 'Fester Blitzer');
  });

  testWidgets('Abbrechen closes overlay', (tester) async {
    await tester.pumpWidget(_buildHud(loggedIn: false));
    await tester.tap(find.text('Blitzer melden'));
    await tester.pump();
    await tester.tap(find.text('Abbrechen'));
    await tester.pump();
    expect(find.byKey(const Key('speed-camera-report-choices')), findsNothing);
  });

  testWidgets('Confirmation appears in German', (tester) async {
    await tester.pumpWidget(
      _buildHud(loggedIn: true, remote: _FakeRemoteRepository()),
    );
    await tester.tap(find.text('Blitzer melden'));
    await tester.pump();
    await tester.tap(find.text('Mobiler Blitzer'));
    await tester.pump();
    expect(find.text('Mobiler Blitzer gemeldet'), findsOneWidget);
  });

  testWidgets('Guest message appears when not logged in', (tester) async {
    await tester.pumpWidget(_buildHud(loggedIn: false));
    await tester.tap(find.text('Blitzer melden'));
    await tester.pump();
    await tester.tap(find.text('Mobiler Blitzer'));
    await tester.pump();
    expect(find.textContaining('Melde dich an'), findsOneWidget);
  });

  testWidgets('Logged-in fake user attempts sync', (tester) async {
    final remote = _FakeRemoteRepository();
    await tester.pumpWidget(_buildHud(loggedIn: true, remote: remote));
    await tester.tap(find.text('Blitzer melden'));
    await tester.pump();
    await tester.tap(find.text('Mobiler Blitzer'));
    await tester.pump();
    expect(remote.uploaded, hasLength(1));
  });

  testWidgets('Compact iPhone layout has no overflow', (tester) async {
    await tester.pumpWidget(
      _buildHud(loggedIn: false, size: const Size(320, 568)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text scale has no overflow', (tester) async {
    await tester.pumpWidget(_buildHud(loggedIn: false, textScaleFactor: 1.6));
    expect(tester.takeException(), isNull);
  });
}

Widget _buildHud({
  required bool loggedIn,
  SpeedCameraReportRepository? remote,
  Size size = const Size(390, 844),
  double textScaleFactor = 1,
}) {
  final repository = CompositeSpeedCameraReportRepository(
    LocalSpeedCameraReportRepository(),
    remoteRepository: remote,
  );
  final controller = SpeedCameraReportController(
    repository,
    isLoggedIn: () => loggedIn,
    currentUserId: () => loggedIn ? 'user-1' : null,
    idFactory: () => DateTime.now().microsecondsSinceEpoch.toString(),
  );
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(textScaleFactor),
    ),
    child: MaterialApp(
      theme: buildAppTheme(),
      home: HudScreen(
        hudRepository: const _FakeHudRepository(),
        locationRepository: _FakeLocationRepository(),
        dataSourceRegistry: const _FakeDataSourceRegistry(),
        permissionRepository: _FakePermissionRepository(),
        cameraLayerBuilder: (_) => const SizedBox.expand(),
        reportController: controller,
      ),
    ),
  );
}

class _FakeRemoteRepository implements SpeedCameraReportRepository {
  final uploaded = <SpeedCameraReport>[];

  @override
  Future<List<SpeedCameraReport>> fetchActiveCommunityReports() async =>
      const [];

  @override
  List<SpeedCameraReport> getLocalReports() => const [];

  @override
  Future<SpeedCameraReport> saveLocal(SpeedCameraReport report) async => report;

  @override
  Future<SpeedCameraReport> upload({
    required SpeedCameraReport report,
    required String userId,
  }) async {
    uploaded.add(report);
    return report.copyWith(
      userId: userId,
      syncStatus: SpeedCameraReportSyncStatus.synced,
    );
  }
}

class _FakeHudRepository implements HudRepository {
  const _FakeHudRepository();
  @override
  List<HudWarningItem> getNearbyWarnings() => const [];
}

class _FakeLocationRepository implements LocationRepository {
  _FakeLocationRepository();
  final ValueNotifier<LocationStatus> _status = ValueNotifier(
    const LocationStatus(
      speedKph: 42,
      headingDegrees: 58,
      gpsFixStatus: GpsFixStatus.strong,
      isMock: false,
      isSpeedEstimatedFromGps: true,
      isHeadingFromCompass: true,
      latitude: 50.1109,
      longitude: 8.6821,
      accuracyMeters: 12,
    ),
  );
  @override
  ValueListenable<LocationStatus> get locationStatusListenable => _status;
}

class _FakePermissionRepository implements PermissionRepository {
  final ValueNotifier<SensorPermissionStatus> _status = ValueNotifier(
    const SensorPermissionStatus(
      camera: SensorPermissionState.granted,
      location: SensorPermissionState.granted,
      motion: SensorPermissionState.unavailable,
    ),
  );
  @override
  ValueListenable<SensorPermissionStatus> get permissionStatusListenable =>
      _status;
}

class _FakeDataSourceRegistry implements DataSourceRegistry {
  const _FakeDataSourceRegistry();
  @override
  List<DataSourceStatus> getRegisteredSources() => const [];
}
