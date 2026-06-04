import 'dart:math' as math;

import '../domain/ar_anchor_projection.dart';

final class GeoArCoordinateMapper {
  const GeoArCoordinateMapper();

  static const double _earthRadiusMeters = 6371000;

  /// Converts WGS84 latitude/longitude into a local tangent plane in meters.
  ///
  /// DriveBot uses the ENU convention used by common Geo-AR pipelines:
  /// east is positive x/right, north is positive forward in the local map, and
  /// up is altitude relative to the user/session origin. Missing target
  /// altitude deliberately resolves to `0` instead of a distance-derived value
  /// so marker height stays horizon-stable until a reliable altitude exists.
  GeoArCoordinate localCoordinate({
    required double currentLatitude,
    required double currentLongitude,
    required double targetLatitude,
    required double targetLongitude,
    double currentAltitude = 0,
    double? targetAltitude,
  }) {
    final enu = eastNorthMeters(
      originLatitude: currentLatitude,
      originLongitude: currentLongitude,
      targetLatitude: targetLatitude,
      targetLongitude: targetLongitude,
    );
    final distance = math.sqrt(
      enu.eastMeters * enu.eastMeters + enu.northMeters * enu.northMeters,
    );
    return GeoArCoordinate(
      eastMeters: enu.eastMeters,
      northMeters: enu.northMeters,
      upMeters: targetAltitude == null ? 0 : targetAltitude - currentAltitude,
      distanceMeters: distance,
      bearingDegrees: bearingDegrees(
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        targetLatitude: targetLatitude,
        targetLongitude: targetLongitude,
      ),
    );
  }

  ArKitCoordinate arKitCoordinateFor(ArLocalCoordinate coordinate) =>
      ArKitCoordinate(
        x: coordinate.eastMeters,
        y: coordinate.upMeters,
        z: -coordinate.northMeters,
      );

  ({double eastMeters, double northMeters}) eastNorthMeters({
    required double originLatitude,
    required double originLongitude,
    required double targetLatitude,
    required double targetLongitude,
  }) {
    final originLat = _degreesToRadians(originLatitude);
    final deltaLat = _degreesToRadians(targetLatitude - originLatitude);
    final deltaLon = _degreesToRadians(targetLongitude - originLongitude);
    return (
      eastMeters: deltaLon * math.cos(originLat) * _earthRadiusMeters,
      northMeters: deltaLat * _earthRadiusMeters,
    );
  }

  double distanceMeters({
    required double currentLatitude,
    required double currentLongitude,
    required double targetLatitude,
    required double targetLongitude,
  }) {
    final enu = eastNorthMeters(
      originLatitude: currentLatitude,
      originLongitude: currentLongitude,
      targetLatitude: targetLatitude,
      targetLongitude: targetLongitude,
    );
    return math.sqrt(
      enu.eastMeters * enu.eastMeters + enu.northMeters * enu.northMeters,
    );
  }

  double bearingDegrees({
    required double currentLatitude,
    required double currentLongitude,
    required double targetLatitude,
    required double targetLongitude,
  }) {
    final fromLat = _degreesToRadians(currentLatitude);
    final toLat = _degreesToRadians(targetLatitude);
    final deltaLon = _degreesToRadians(targetLongitude - currentLongitude);
    final y = math.sin(deltaLon) * math.cos(toLat);
    final x =
        math.cos(fromLat) * math.sin(toLat) -
        math.sin(fromLat) * math.cos(toLat) * math.cos(deltaLon);
    return (_radiansToDegrees(math.atan2(y, x)) + 360) % 360;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
  double _radiansToDegrees(double radians) => radians * 180 / math.pi;
}

final class GeoArCoordinate extends ArLocalCoordinate {
  const GeoArCoordinate({
    required super.eastMeters,
    required super.northMeters,
    required this.distanceMeters,
    required this.bearingDegrees,
    super.upMeters,
  });

  final double distanceMeters;
  final double bearingDegrees;
}
