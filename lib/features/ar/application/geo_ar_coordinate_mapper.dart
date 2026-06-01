import 'dart:math' as math;

import '../domain/ar_anchor_projection.dart';

final class GeoArCoordinateMapper {
  const GeoArCoordinateMapper();

  static const double _earthRadiusMeters = 6371000;

  GeoArCoordinate localCoordinate({
    required double currentLatitude,
    required double currentLongitude,
    required double targetLatitude,
    required double targetLongitude,
    double currentAltitude = 0,
    double? targetAltitude,
  }) {
    final distance = distanceMeters(
      currentLatitude: currentLatitude,
      currentLongitude: currentLongitude,
      targetLatitude: targetLatitude,
      targetLongitude: targetLongitude,
    );
    final bearing = bearingDegrees(
      currentLatitude: currentLatitude,
      currentLongitude: currentLongitude,
      targetLatitude: targetLatitude,
      targetLongitude: targetLongitude,
    );
    final radians = _degreesToRadians(bearing);
    return GeoArCoordinate(
      eastMeters: math.sin(radians) * distance,
      northMeters: math.cos(radians) * distance,
      upMeters: (targetAltitude ?? currentAltitude) - currentAltitude,
      distanceMeters: distance,
      bearingDegrees: bearing,
    );
  }

  ArKitCoordinate arKitCoordinateFor(ArLocalCoordinate coordinate) =>
      ArKitCoordinate(
        x: coordinate.eastMeters,
        y: coordinate.upMeters,
        z: -coordinate.northMeters,
      );

  double distanceMeters({
    required double currentLatitude,
    required double currentLongitude,
    required double targetLatitude,
    required double targetLongitude,
  }) {
    final fromLat = _degreesToRadians(currentLatitude);
    final toLat = _degreesToRadians(targetLatitude);
    final deltaLat = _degreesToRadians(targetLatitude - currentLatitude);
    final deltaLon = _degreesToRadians(targetLongitude - currentLongitude);
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(fromLat) *
            math.cos(toLat) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    return _earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
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
