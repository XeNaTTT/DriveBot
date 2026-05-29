import 'dart:math' as math;

import '../../hud/domain/hud_warning_item.dart';
import '../../warnings/domain/warning_repository.dart';
import '../../warnings/domain/warning_repository_result.dart';
import '../../warnings/domain/warning_request.dart';
import '../domain/speed_camera_report.dart';
import '../domain/speed_camera_report_repository.dart';

final class CommunitySpeedCameraWarningRepository implements WarningRepository {
  const CommunitySpeedCameraWarningRepository(
    this._repository, {
    this.radiusMeters = 5000,
  });

  final SpeedCameraReportRepository _repository;
  final int radiusMeters;

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    if (!request.hasCurrentLocation) {
      return const WarningRepositoryResult.empty();
    }

    try {
      final now = DateTime.now().toUtc();
      final reports = await _repository.fetchActiveCommunityReports();
      final warnings =
          reports
              .where(
                (report) => report.isActiveAt(now) && report.hasCoordinates,
              )
              .map((report) => _toWarning(report, request))
              .where((warning) => warning.distanceMeters <= radiusMeters)
              .toList(growable: false)
            ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return warnings.isEmpty
          ? const WarningRepositoryResult.empty()
          : WarningRepositoryResult.live(warnings.take(3).toList());
    } on Object catch (error) {
      return WarningRepositoryResult.failure(error.toString());
    }
  }

  HudWarningItem _toWarning(SpeedCameraReport report, WarningRequest request) {
    final latitude = report.latitude!;
    final longitude = report.longitude!;
    final distance = _distanceMeters(
      request.latitude,
      request.longitude,
      latitude,
      longitude,
    ).round();
    return HudWarningItem(
      type: WarningType.speedCamera,
      title: report.type.germanLabel,
      detail: 'Quelle: Community',
      distanceMeters: distance,
      bearingDegrees: _bearingDegrees(
        request.latitude,
        request.longitude,
        latitude,
        longitude,
      ).round(),
      severity: 5,
      source: 'Community',
      latitude: latitude,
      longitude: longitude,
      validFrom: report.createdAt,
      validTo: report.expiresAt,
    );
  }

  double _distanceMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _radians(endLatitude - startLatitude);
    final dLon = _radians(endLongitude - startLongitude);
    final lat1 = _radians(startLatitude);
    final lat2 = _radians(endLatitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _bearingDegrees(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final lat1 = _radians(startLatitude);
    final lat2 = _radians(endLatitude);
    final dLon = _radians(endLongitude - startLongitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
