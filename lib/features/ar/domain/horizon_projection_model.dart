import '../../hud/domain/hud_warning_item.dart';
import 'ar_runtime_state.dart';

final class HorizonProjectionModel {
  const HorizonProjectionModel({
    this.defaultHorizonFraction = 0.45,
    this.verticalFieldOfViewDegrees = 55,
    this.minTopFraction = 0.20,
    this.maxTopFraction = 0.68,
    this.nearDistanceMeters = 1200,
    this.maxPitchDegrees = 24,
    this.maxRollDegrees = 28,
  });

  final double defaultHorizonFraction;
  final double verticalFieldOfViewDegrees;
  final double minTopFraction;
  final double maxTopFraction;
  final double nearDistanceMeters;
  final double maxPitchDegrees;
  final double maxRollDegrees;

  double horizonY({
    required double screenHeight,
    double safeAreaTop = 0,
    double safeAreaBottom = 0,
    double? devicePitchDegrees,
    double? deviceRollDegrees,
    ArTrackingQuality trackingQuality = ArTrackingQuality.unknown,
  }) {
    final usableHeight = _usableHeight(
      screenHeight,
      safeAreaTop,
      safeAreaBottom,
    );
    final base = safeAreaTop + (usableHeight * defaultHorizonFraction);
    final pitch = _finiteOrNull(
      devicePitchDegrees,
    )?.clamp(-maxPitchDegrees, maxPitchDegrees);
    final pitchOffset = pitch == null
        ? 0.0
        : (pitch / verticalFieldOfViewDegrees) * usableHeight;
    final roll = _finiteOrNull(
      deviceRollDegrees,
    )?.abs().clamp(0, maxRollDegrees);
    final rollDamping = roll == null
        ? 1.0
        : 1.0 - ((roll / maxRollDegrees) * 0.18);
    final trackingDamping = trackingQuality == ArTrackingQuality.limited
        ? 0.65
        : 1.0;
    return _clampY(
      base + (pitchOffset * rollDamping * trackingDamping),
      screenHeight: screenHeight,
      safeAreaTop: safeAreaTop,
      safeAreaBottom: safeAreaBottom,
    );
  }

  double markerTopFraction({
    required double screenHeight,
    double safeAreaTop = 0,
    double safeAreaBottom = 0,
    required double distanceMeters,
    required WarningType type,
    double? devicePitchDegrees,
    double? deviceRollDegrees,
    ArTrackingQuality trackingQuality = ArTrackingQuality.unknown,
  }) {
    final horizon = horizonY(
      screenHeight: screenHeight,
      safeAreaTop: safeAreaTop,
      safeAreaBottom: safeAreaBottom,
      devicePitchDegrees: devicePitchDegrees,
      deviceRollDegrees: deviceRollDegrees,
      trackingQuality: trackingQuality,
    );
    final distance = distanceMeters.clamp(0, 3000).toDouble();
    final nearFactor = distance >= nearDistanceMeters
        ? 0.0
        : (nearDistanceMeters - distance) / nearDistanceMeters;
    final typeBias = switch (type) {
      WarningType.speedCamera => 0.070,
      WarningType.chargingStation => 0.045,
      WarningType.speedLimit => 0.040,
      WarningType.roadwork => 0.036,
      WarningType.weather || WarningType.notice => 0.024,
    };
    final movementScale = trackingQuality == ArTrackingQuality.limited
        ? 0.55
        : 1.0;
    final topY =
        horizon + (nearFactor * typeBias * screenHeight * movementScale);
    return (_clampY(
          topY,
          screenHeight: screenHeight,
          safeAreaTop: safeAreaTop,
          safeAreaBottom: safeAreaBottom,
        ) /
        screenHeight);
  }

  double _usableHeight(
    double screenHeight,
    double safeAreaTop,
    double safeAreaBottom,
  ) => (screenHeight - safeAreaTop - safeAreaBottom)
      .clamp(1, double.infinity)
      .toDouble();

  double _clampY(
    double y, {
    required double screenHeight,
    required double safeAreaTop,
    required double safeAreaBottom,
  }) {
    final minY = safeAreaTop + (screenHeight * minTopFraction);
    final maxY =
        screenHeight - safeAreaBottom - (screenHeight * (1 - maxTopFraction));
    return y.clamp(minY, maxY).toDouble();
  }

  double? _finiteOrNull(double? value) =>
      value == null || !value.isFinite ? null : value;
}
