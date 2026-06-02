import 'dart:math' as math;

final class ArProjectionSmoothingConfig {
  const ArProjectionSmoothingConfig({
    this.headingSmoothingFactor = 0.32,
    this.pitchSmoothingFactor = 0.30,
    this.rollSmoothingFactor = 0.24,
    this.markerSmoothingFactor = 0.35,
    this.limitedTrackingMarkerSmoothingFactor = 0.22,
    this.minPixelMovementThreshold = 2.0,
    this.minHeadingChangeDegrees = 0.7,
    this.minPitchChangeDegrees = 0.35,
  });

  final double headingSmoothingFactor;
  final double pitchSmoothingFactor;
  final double rollSmoothingFactor;
  final double markerSmoothingFactor;
  final double limitedTrackingMarkerSmoothingFactor;
  final double minPixelMovementThreshold;
  final double minHeadingChangeDegrees;
  final double minPitchChangeDegrees;
}

final class ArProjectionSmoothing {
  const ArProjectionSmoothing._();

  static double smoothCircularDegrees({
    required double previous,
    required double current,
    required double factor,
    double minChangeDegrees = 0,
  }) {
    final delta = shortestDeltaDegrees(previous: previous, current: current);
    if (delta.abs() < minChangeDegrees) return normalizeDegrees(previous);
    return normalizeDegrees(previous + (delta * factor));
  }

  static double smoothLinear({
    required double previous,
    required double current,
    required double factor,
    double minChange = 0,
  }) {
    final delta = current - previous;
    if (delta.abs() < minChange) return previous;
    return previous + (delta * factor);
  }

  static double shortestDeltaDegrees({
    required double previous,
    required double current,
  }) {
    var delta = normalizeDegrees(current) - normalizeDegrees(previous);
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return delta;
  }

  static double normalizeDegrees(double degrees) {
    final normalized = degrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  static double normalizedMovementThreshold({
    required double pixelThreshold,
    required double extentPixels,
  }) => pixelThreshold / math.max(1, extentPixels);
}
