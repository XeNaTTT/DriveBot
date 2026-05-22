enum GpsFixStatus { strong, moderate, weak, unavailable }

class LocationStatus {
  const LocationStatus({
    required this.speedKph,
    required this.headingDegrees,
    required this.gpsFixStatus,
    required this.isMock,
    required this.isSpeedEstimatedFromGps,
  });

  final int speedKph;
  final int headingDegrees;
  final GpsFixStatus gpsFixStatus;
  final bool isMock;
  final bool isSpeedEstimatedFromGps;

  String get cardinalHeading {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((headingDegrees % 360) / 45).round() % 8;
    return dirs[index];
  }
}
