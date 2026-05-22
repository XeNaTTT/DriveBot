enum GpsFixStatus { strong, moderate, weak }

class LocationStatus {
  const LocationStatus({
    required this.speedKph,
    required this.headingDegrees,
    required this.gpsFixStatus,
  });

  final int speedKph;
  final int headingDegrees;
  final GpsFixStatus gpsFixStatus;

  String get cardinalHeading {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((headingDegrees % 360) / 45).round() % 8;
    return dirs[index];
  }
}
