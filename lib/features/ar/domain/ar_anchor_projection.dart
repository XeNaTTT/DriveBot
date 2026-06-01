import 'ar_geo_anchor_candidate.dart';

class ArLocalCoordinate {
  const ArLocalCoordinate({
    required this.eastMeters,
    required this.northMeters,
    this.upMeters = 0,
  });

  final double eastMeters;
  final double northMeters;
  final double upMeters;
}

final class ArKitCoordinate {
  const ArKitCoordinate({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;
}

final class ArAnchorProjection {
  const ArAnchorProjection({
    required this.candidate,
    required this.localCoordinate,
    required this.arkitCoordinate,
    required this.normalizedX,
    required this.top,
    required this.usesWorldAnchor,
  });

  final ArGeoAnchorCandidate candidate;
  final ArLocalCoordinate localCoordinate;
  final ArKitCoordinate arkitCoordinate;
  final double normalizedX;
  final double top;
  final bool usesWorldAnchor;
}
