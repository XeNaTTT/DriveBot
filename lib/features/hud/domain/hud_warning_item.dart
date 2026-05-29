enum WarningType {
  speedCamera,
  speedLimit,
  roadwork,
  weather,
  chargingStation,
  notice,
}

class HudWarningItem {
  const HudWarningItem({
    required this.type,
    required this.title,
    required this.detail,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.severity,
  });

  final WarningType type;
  final String title;
  final String detail;
  final int distanceMeters;
  final int bearingDegrees;
  final int severity;
}
