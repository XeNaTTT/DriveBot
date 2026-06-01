import '../../hud/domain/hud_warning_item.dart';

/// UI-agnostic warning model shared by warning data sources before HUD mapping.
class DriveWarning {
  const DriveWarning({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.sourceLabel,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.severity,
    this.validFrom,
    this.validTo,
  });

  final String id;
  final DriveWarningKind kind;
  final String title;
  final String description;
  final String sourceLabel;
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final int bearingDegrees;
  final int severity;
  final DateTime? validFrom;
  final DateTime? validTo;

  bool get isExpired => validTo != null && validTo!.isBefore(DateTime.now());

  HudWarningItem toHudWarning() => HudWarningItem(
    id: id,
    type: kind.warningType,
    title: title,
    detail: description,
    distanceMeters: distanceMeters,
    bearingDegrees: bearingDegrees,
    severity: severity,
    source: sourceLabel,
    latitude: latitude,
    longitude: longitude,
    validFrom: validFrom,
    validTo: validTo,
    typeLabel: kind.germanLabel,
  );
}

enum DriveWarningKind {
  closure('Sperrung', 1, WarningType.notice),
  roadwork('Baustelle', 2, WarningType.roadwork),
  restriction('Verkehrseinschränkung', 3, WarningType.notice),
  incident('Verkehrsmeldung', 4, WarningType.notice);

  const DriveWarningKind(this.germanLabel, this.priority, this.warningType);

  final String germanLabel;
  final int priority;
  final WarningType warningType;
}
