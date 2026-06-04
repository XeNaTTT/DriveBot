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
    this.id,
    this.typeLabel,
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
  final String? id;
  final String? typeLabel;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool isActiveAt(DateTime now) {
    if (validFrom != null && validFrom!.isAfter(now)) return false;
    if (validTo == null || validTo!.isAfter(now)) return true;
    return !_isCommunitySpeedCamera;
  }

  bool get _isCommunitySpeedCamera {
    if (type != WarningType.speedCamera) return false;
    final normalizedSource = source?.toLowerCase();
    if (normalizedSource == null || !normalizedSource.contains('community')) {
      return false;
    }
    final normalizedTitle = title.toLowerCase();
    final normalizedDetail = detail.toLowerCase();
    return normalizedTitle.contains('blitzer') &&
        !normalizedTitle.contains('community') &&
        !normalizedDetail.contains('feste kamera');
  }

  String get stableId {
    if (id != null && id!.isNotEmpty) return id!;
    final locationPart = hasCoordinates
        ? '${latitude!.toStringAsFixed(6)}|${longitude!.toStringAsFixed(6)}'
        : 'bearing:${bearingDegrees.toString()}';
    return [
      type.name,
      source ?? 'lokal',
      roadId ?? 'ohne-strasse',
      title,
      detail,
      locationPart,
    ].join('|');
  }
}
