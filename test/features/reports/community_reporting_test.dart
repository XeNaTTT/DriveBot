import 'dart:async';

import 'package:driveassistant_ar/features/camera/domain/camera_runtime_state.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:driveassistant_ar/features/location/domain/sensor_permission_status.dart';
import 'package:driveassistant_ar/features/reports/application/speed_camera_report_controller.dart';
import 'package:driveassistant_ar/features/reports/data/community_speed_camera_warning_repository.dart';
import 'package:driveassistant_ar/features/reports/data/composite_speed_camera_report_repository.dart';
import 'package:driveassistant_ar/features/reports/data/local_speed_camera_report_repository.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report_confidence.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report_repository.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report_sync_status.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report_type.dart';
import 'package:driveassistant_ar/features/sensors/domain/sensor_runtime_state.dart';
import 'package:driveassistant_ar/features/warnings/domain/warning_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase mapping', () {
    test('Mobile report maps to report_type mobile', () {
      final report = _report(SpeedCameraReportType.mobile);
      expect(report.toSupabaseInsert('u1')['report_type'], 'mobile');
    });

    test('Fixed report maps to report_type fixed', () {
      final report = _report(SpeedCameraReportType.fixed);
      expect(report.toSupabaseInsert('u1')['report_type'], 'fixed');
    });
  });

  group('controller sync behavior', () {
    test('Report with coordinates can be uploaded when logged in', () async {
      final remote = _FakeRemoteRepository();
      final repository = CompositeSpeedCameraReportRepository(
        LocalSpeedCameraReportRepository(),
        remoteRepository: remote,
      );
      final controller = _controller(repository, loggedIn: true);

      final result = await controller.report(
        type: SpeedCameraReportType.mobile,
        location: _liveLocation,
        cameraState: const CameraRuntimeState.ready(
          currentZoomLevel: 1,
          minZoom: 0.5,
          maxZoom: 1,
        ),
        runtime: _runtime(_liveLocation),
      );

      expect(remote.uploadAttempts, 1);
      expect(result.syncStatus, SpeedCameraReportSyncStatus.synced);
      expect(controller.message, 'Mobiler Blitzer gemeldet');
    });

    test('Report without coordinates remains local only', () async {
      final remote = _FakeRemoteRepository();
      final repository = CompositeSpeedCameraReportRepository(
        LocalSpeedCameraReportRepository(),
        remoteRepository: remote,
      );
      final controller = _controller(repository, loggedIn: true);

      final result = await controller.report(
        type: SpeedCameraReportType.mobile,
        location: _noLocation,
        cameraState: const CameraRuntimeState.initializing(),
        runtime: _runtime(_noLocation),
      );

      expect(remote.uploadAttempts, 0);
      expect(result.syncStatus, SpeedCameraReportSyncStatus.localOnly);
    });

    test('Guest report remains local only', () async {
      final remote = _FakeRemoteRepository();
      final repository = CompositeSpeedCameraReportRepository(
        LocalSpeedCameraReportRepository(),
        remoteRepository: remote,
      );
      final controller = _controller(repository, loggedIn: false);

      final result = await controller.report(
        type: SpeedCameraReportType.fixed,
        location: _liveLocation,
        cameraState: const CameraRuntimeState.initializing(),
        runtime: _runtime(_liveLocation),
      );

      expect(remote.uploadAttempts, 0);
      expect(result.syncStatus, SpeedCameraReportSyncStatus.localOnly);
      expect(controller.message, contains('Melde dich an'));
    });

    test('Supabase insert success => synced', () async {
      final repository = CompositeSpeedCameraReportRepository(
        LocalSpeedCameraReportRepository(),
        remoteRepository: _FakeRemoteRepository(),
      );

      final result = await repository.upload(
        report: _report(SpeedCameraReportType.mobile),
        userId: 'user-1',
      );

      expect(result.syncStatus, SpeedCameraReportSyncStatus.synced);
    });

    test('Supabase insert failure => failed/local fallback', () async {
      final repository = CompositeSpeedCameraReportRepository(
        LocalSpeedCameraReportRepository(),
        remoteRepository: _FakeRemoteRepository(throwsOnUpload: true),
      );

      final result = await repository.upload(
        report: _report(SpeedCameraReportType.mobile),
        userId: 'user-1',
      );

      expect(result.syncStatus, SpeedCameraReportSyncStatus.failed);
    });
  });

  group('community warning mapping', () {
    test('Active community rows map to warnings', () async {
      final repository = CommunitySpeedCameraWarningRepository(
        _FakeReportRepository([_report(SpeedCameraReportType.mobile)]),
      );

      final result = await repository.getWarnings(_request);

      expect(result.warnings.single.title, 'Mobiler Blitzer');
      expect(result.warnings.single.detail, 'Quelle: Community');
    });

    test('Expired community rows are ignored', () async {
      final repository = CommunitySpeedCameraWarningRepository(
        _FakeReportRepository([
          _report(
            SpeedCameraReportType.fixed,
            expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
          ),
        ]),
      );

      final result = await repository.getWarnings(_request);

      expect(result.warnings, isEmpty);
    });

    test('Hidden/rejected rows are ignored defensively', () async {
      final repository = CommunitySpeedCameraWarningRepository(
        _FakeReportRepository([
          _report(SpeedCameraReportType.fixed, moderationStatus: 'hidden'),
          _report(SpeedCameraReportType.fixed, moderationStatus: 'rejected'),
        ]),
      );

      final result = await repository.getWarnings(_request);

      expect(result.warnings, isEmpty);
    });
  });
}

SpeedCameraReportController _controller(
  CompositeSpeedCameraReportRepository repository, {
  required bool loggedIn,
}) => SpeedCameraReportController(
  repository,
  isLoggedIn: () => loggedIn,
  currentUserId: () => loggedIn ? 'user-1' : null,
  idFactory: () => 'local-1',
  now: () => DateTime.utc(2026, 5, 29, 12),
);

SpeedCameraReport _report(
  SpeedCameraReportType type, {
  DateTime? expiresAt,
  String moderationStatus = 'active',
}) => SpeedCameraReport(
  id: 'r-${type.storageValue}-$moderationStatus',
  type: type,
  createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
  expiresAt: expiresAt ?? DateTime.now().toUtc().add(const Duration(days: 1)),
  latitude: 50.1118,
  longitude: 8.6841,
  headingDegrees: 58,
  speedKmh: 42,
  appMode: SpeedCameraReportAppMode.liveAr,
  confidence: SpeedCameraReportConfidence.high,
  moderationStatus: moderationStatus,
);

const _liveLocation = LocationStatus(
  speedKph: 42,
  headingDegrees: 58,
  gpsFixStatus: GpsFixStatus.strong,
  isMock: false,
  isSpeedEstimatedFromGps: true,
  isHeadingFromCompass: true,
  latitude: 50.1109,
  longitude: 8.6821,
  accuracyMeters: 12,
);

const _noLocation = LocationStatus(
  speedKph: 0,
  headingDegrees: 0,
  gpsFixStatus: GpsFixStatus.unavailable,
  isMock: true,
  isSpeedEstimatedFromGps: false,
);

SensorRuntimeState _runtime(LocationStatus location) => SensorRuntimeState(
  cameraAvailable: true,
  locationStatus: location,
  permissionStatus: const SensorPermissionStatus(
    camera: SensorPermissionState.granted,
    location: SensorPermissionState.granted,
    motion: SensorPermissionState.unavailable,
  ),
  motionStatus: const MotionRuntimeState.unavailable(),
);

const _request = WarningRequest(
  latitude: 50.1109,
  longitude: 8.6821,
  headingDegrees: 58,
);

class _FakeRemoteRepository implements SpeedCameraReportRepository {
  _FakeRemoteRepository({this.throwsOnUpload = false});

  final bool throwsOnUpload;
  int uploadAttempts = 0;

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
    uploadAttempts++;
    if (throwsOnUpload) throw TimeoutException('offline');
    return report.copyWith(
      userId: userId,
      syncStatus: SpeedCameraReportSyncStatus.synced,
    );
  }
}

class _FakeReportRepository implements SpeedCameraReportRepository {
  const _FakeReportRepository(this.reports);
  final List<SpeedCameraReport> reports;

  @override
  Future<List<SpeedCameraReport>> fetchActiveCommunityReports() async =>
      reports;

  @override
  List<SpeedCameraReport> getLocalReports() => reports;

  @override
  Future<SpeedCameraReport> saveLocal(SpeedCameraReport report) async => report;

  @override
  Future<SpeedCameraReport> upload({
    required SpeedCameraReport report,
    required String userId,
  }) async => report;
}
