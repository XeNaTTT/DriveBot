import '../../hud/domain/hud_warning_item.dart';
import '../../reports/domain/speed_camera_report.dart';

enum ArAnchorType { warning, speedCamera, chargingStation, navigationTarget }

enum ArAnchorSeverity { low, medium, high, critical }

final class ArAnchorModel {
  const ArAnchorModel({
    required this.id,
    required this.type,
    required this.label,
    required this.severity,
    required this.source,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.bearingDegrees,
    this.relativeBearing,
    this.expiresAt,
    this.confidence,
  });

  final String id;
  final ArAnchorType type;
  final double? latitude;
  final double? longitude;
  final int? distanceMeters;
  final int? bearingDegrees;
  final double? relativeBearing;
  final String label;
  final ArAnchorSeverity severity;
  final String source;
  final DateTime? expiresAt;
  final double? confidence;

  bool isVisibleAt(DateTime now) =>
      expiresAt == null || expiresAt!.isAfter(now);

  static ArAnchorModel fromWarning(
    HudWarningItem warning, {
    required double? relativeBearing,
  }) => ArAnchorModel(
    id: 'warning:${warning.type.name}:${warning.title}:${warning.distanceMeters}',
    type: switch (warning.type) {
      WarningType.speedCamera => ArAnchorType.speedCamera,
      WarningType.chargingStation => ArAnchorType.chargingStation,
      _ => ArAnchorType.warning,
    },
    latitude: warning.latitude,
    longitude: warning.longitude,
    distanceMeters: warning.distanceMeters,
    bearingDegrees: warning.bearingDegrees,
    relativeBearing: relativeBearing,
    label: warning.title,
    severity: _severityFor(warning.severity),
    source: warning.source ?? 'hud',
    expiresAt: warning.validTo,
  );

  static ArAnchorModel fromSpeedCameraReport(
    SpeedCameraReport report, {
    double? distanceMeters,
    double? relativeBearing,
  }) => ArAnchorModel(
    id: 'speed-camera:${report.id}',
    type: ArAnchorType.speedCamera,
    latitude: report.latitude,
    longitude: report.longitude,
    distanceMeters: distanceMeters?.round(),
    bearingDegrees: report.headingDegrees?.round(),
    relativeBearing: relativeBearing,
    label: report.type.germanLabel,
    severity: ArAnchorSeverity.high,
    source: report.source,
    expiresAt: report.expiresAt,
    confidence: switch (report.confidence.name) {
      'high' => 0.9,
      'medium' => 0.6,
      _ => 0.35,
    },
  );

  static ArAnchorSeverity _severityFor(int severity) {
    if (severity >= 5) return ArAnchorSeverity.critical;
    if (severity >= 4) return ArAnchorSeverity.high;
    if (severity >= 2) return ArAnchorSeverity.medium;
    return ArAnchorSeverity.low;
  }
}
