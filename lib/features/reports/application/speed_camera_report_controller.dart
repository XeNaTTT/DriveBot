import 'package:flutter/foundation.dart';

import '../../camera/domain/camera_runtime_state.dart';
import '../../location/domain/location_status.dart';
import '../../sensors/domain/sensor_runtime_state.dart';
import '../data/composite_speed_camera_report_repository.dart';
import '../domain/speed_camera_report.dart';
import '../domain/speed_camera_report_confidence.dart';
import '../domain/speed_camera_report_sync_status.dart';
import '../domain/speed_camera_report_type.dart';

final class SpeedCameraReportController extends ChangeNotifier {
  SpeedCameraReportController(
    this._repository, {
    required this.isLoggedIn,
    required this.currentUserId,
    DateTime Function()? now,
    String Function()? idFactory,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _idFactory =
           idFactory ??
           (() => DateTime.now().microsecondsSinceEpoch.toString());

  final CompositeSpeedCameraReportRepository _repository;
  final bool Function() isLoggedIn;
  final String? Function() currentUserId;
  final DateTime Function() _now;
  final String Function() _idFactory;

  String? _message;
  bool _isReporting = false;

  String? get message => _message;
  bool get isReporting => _isReporting;

  Future<SpeedCameraReport> report({
    required SpeedCameraReportType type,
    required LocationStatus location,
    required CameraRuntimeState cameraState,
    required SensorRuntimeState runtime,
  }) async {
    if (_isReporting) {
      return _repository.getLocalReports().last;
    }
    _isReporting = true;
    notifyListeners();

    final report = _buildReport(
      type: type,
      location: location,
      cameraState: cameraState,
      runtime: runtime,
    );
    final local = await _repository.saveLocal(report);

    SpeedCameraReport completed = local;
    final userId = currentUserId();
    final shouldSync =
        isLoggedIn() &&
        userId != null &&
        report.hasCoordinates &&
        _repository.hasRemoteSync;
    if (shouldSync) {
      completed = await _repository.upload(report: local, userId: userId);
    }

    _message = _messageFor(type, completed, loggedIn: isLoggedIn());
    _isReporting = false;
    notifyListeners();
    return completed;
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  SpeedCameraReport _buildReport({
    required SpeedCameraReportType type,
    required LocationStatus location,
    required CameraRuntimeState cameraState,
    required SensorRuntimeState runtime,
  }) {
    final hasLocation =
        location.hasLiveLocation &&
        location.latitude != null &&
        location.longitude != null;
    return SpeedCameraReport(
      id: _idFactory(),
      type: type,
      createdAt: _now(),
      latitude: hasLocation ? location.latitude : null,
      longitude: hasLocation ? location.longitude : null,
      locationAccuracyMeters: location.accuracyMeters,
      headingDegrees: location.hasLiveHeading
          ? location.headingDegrees.toDouble()
          : null,
      speedKmh: location.isSpeedEstimatedFromGps
          ? location.speedKph.toDouble()
          : null,
      cameraZoomLabel: cameraState.cameraAvailable
          ? cameraState.currentZoomLabel
          : null,
      appMode: runtime.isFullyLiveMode
          ? SpeedCameraReportAppMode.liveAr
          : (hasLocation
                ? SpeedCameraReportAppMode.partialLive
                : SpeedCameraReportAppMode.fallback),
      confidence: hasLocation
          ? (location.hasLiveHeading
                ? SpeedCameraReportConfidence.high
                : SpeedCameraReportConfidence.medium)
          : SpeedCameraReportConfidence.low,
      syncStatus: SpeedCameraReportSyncStatus.pending,
    );
  }

  String _messageFor(
    SpeedCameraReportType type,
    SpeedCameraReport report, {
    required bool loggedIn,
  }) {
    if (report.syncStatus == SpeedCameraReportSyncStatus.synced) {
      return '${type.germanLabel} gemeldet';
    }
    if (!loggedIn) {
      return 'Lokal gespeichert. Melde dich an, um Blitzer mit der Community zu teilen.';
    }
    if (report.syncStatus == SpeedCameraReportSyncStatus.failed) {
      return 'Meldung lokal gespeichert. Synchronisierung fehlgeschlagen.';
    }
    return 'Meldung lokal gespeichert';
  }
}
