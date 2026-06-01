import 'ar_anchor_model.dart';

final class ArGeoAnchorCandidate {
  const ArGeoAnchorCandidate({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.relativeBearing,
    required this.source,
    required this.label,
    required this.type,
    required this.confidence,
    this.altitude,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double distanceMeters;
  final double bearingDegrees;
  final double relativeBearing;
  final String source;
  final String label;
  final ArAnchorType type;
  final double confidence;
}
