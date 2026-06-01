import '../../hud/domain/hud_warning_item.dart';
import '../../location/domain/location_status.dart';
import '../../reports/domain/speed_camera_report.dart';
import '../application/geo_ar_coordinate_mapper.dart';
import 'ar_anchor_model.dart';
import 'ar_geo_anchor_candidate.dart';
import 'ar_info_object.dart';
import 'ar_marker_model.dart';

final class ArAnchorCandidateMapper {
  const ArAnchorCandidateMapper([
    this._coordinateMapper = const GeoArCoordinateMapper(),
  ]);

  final GeoArCoordinateMapper _coordinateMapper;

  List<ArAnchorModel> fromMarkers(List<ArMarkerModel> markers) => markers
      .map(
        (marker) => ArAnchorModel.fromWarning(
          marker.infoObject.warning,
          relativeBearing: marker.relativeBearing,
        ),
      )
      .toList(growable: false);

  List<ArGeoAnchorCandidate> geoCandidatesFromObjects({
    required List<ArInfoObject> objects,
    required LocationStatus location,
  }) {
    final userLat = location.latitude;
    final userLon = location.longitude;
    if (!location.hasLiveLocation || userLat == null || userLon == null) {
      return const [];
    }

    return objects
        .map((object) => _candidateFor(object, location, userLat, userLon))
        .whereType<ArGeoAnchorCandidate>()
        .toList(growable: false);
  }

  List<ArAnchorModel> fromSpeedCameraReports(
    List<SpeedCameraReport> reports, {
    required DateTime now,
  }) => reports
      .where((report) => report.isActiveAt(now) && report.hasCoordinates)
      .map(ArAnchorModel.fromSpeedCameraReport)
      .toList(growable: false);

  ArGeoAnchorCandidate? _candidateFor(
    ArInfoObject object,
    LocationStatus location,
    double userLat,
    double userLon,
  ) {
    final warning = object.warning;
    final latitude = warning.latitude;
    final longitude = warning.longitude;
    if (latitude == null || longitude == null) return null;

    final coordinate = _coordinateMapper.localCoordinate(
      currentLatitude: userLat,
      currentLongitude: userLon,
      targetLatitude: latitude,
      targetLongitude: longitude,
    );
    final relativeBearing = _normalizeAngle(
      coordinate.bearingDegrees - location.headingDegrees,
    );

    return ArGeoAnchorCandidate(
      id: object.id,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: coordinate.distanceMeters,
      bearingDegrees: coordinate.bearingDegrees,
      relativeBearing: relativeBearing,
      source: object.sourceLabel,
      label: object.title,
      type: switch (object.type) {
        WarningType.speedCamera => ArAnchorType.speedCamera,
        WarningType.chargingStation => ArAnchorType.chargingStation,
        _ => ArAnchorType.warning,
      },
      confidence: _confidenceFor(object),
    );
  }

  double _confidenceFor(ArInfoObject object) =>
      switch (object.warning.severity) {
        >= 5 => 0.95,
        >= 4 => 0.85,
        >= 2 => 0.65,
        _ => 0.45,
      };

  double _normalizeAngle(double degrees) {
    var normalized = degrees % 360;
    if (normalized > 180) normalized -= 360;
    if (normalized < -180) normalized += 360;
    return normalized;
  }
}
