import 'dart:math' as math;

class DistanceCalculator {
  const DistanceCalculator();

  static const double _earthRadiusMeters = 6371000;

  double distanceMeters({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) {
    final fromLat = _degreesToRadians(fromLatitude);
    final toLat = _degreesToRadians(toLatitude);
    final deltaLat = _degreesToRadians(toLatitude - fromLatitude);
    final deltaLon = _degreesToRadians(toLongitude - fromLongitude);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(fromLat) *
            math.cos(toLat) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
}
