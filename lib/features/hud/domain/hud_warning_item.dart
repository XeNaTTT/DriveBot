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
    this.source,
    this.roadId,
    this.latitude,
    this.longitude,
    this.validFrom,
    this.validTo,
  });

  final WarningType type;
  final String title;
  final String detail;
  final int distanceMeters;
  final int bearingDegrees;
  final int severity;
  final String? source;
  final String? roadId;
  final double? latitude;
  final double? longitude;
  final DateTime? validFrom;
  final DateTime? validTo;
}
