class ArMarkerPosition {
  const ArMarkerPosition({
    required this.horizontalAlignment,
    required this.verticalBias,
    required this.normalizedDistance,
  });

  final double horizontalAlignment;
  final double verticalBias;
  final double normalizedDistance;
}

class BearingToArPositionMapper {
  const BearingToArPositionMapper({
    this.maxRenderableDistanceMeters = 1500,
    this.horizontalFieldOfViewDegrees = 80,
  });

  final int maxRenderableDistanceMeters;
  final int horizontalFieldOfViewDegrees;

  ArMarkerPosition map({
    required int userHeadingDegrees,
    required int warningBearingDegrees,
    required int warningDistanceMeters,
  }) {
    final relativeDegrees = _normalizeRelativeAngle(
      warningBearingDegrees - userHeadingDegrees,
    );

    final halfFov = horizontalFieldOfViewDegrees / 2;
    final horizontal = (relativeDegrees / halfFov).clamp(-1.0, 1.0);

    final clampedDistance = warningDistanceMeters.clamp(0, maxRenderableDistanceMeters);
    final normalizedDistance = clampedDistance / maxRenderableDistanceMeters;
    final verticalBias = (1 - normalizedDistance).clamp(0.2, 1.0);

    return ArMarkerPosition(
      horizontalAlignment: horizontal,
      verticalBias: verticalBias,
      normalizedDistance: normalizedDistance,
    );
  }

  double _normalizeRelativeAngle(int angle) {
    final normalized = ((angle + 540) % 360) - 180;
    return normalized.toDouble();
  }
}
