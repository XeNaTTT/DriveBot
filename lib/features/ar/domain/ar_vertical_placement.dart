import '../../hud/domain/hud_warning_item.dart';
import 'ar_info_object.dart';

final class ArVerticalPlacement {
  const ArVerticalPlacement({
    this.minTop = 0.22,
    this.maxTop = 0.62,
    this.horizonTop = 0.38,
  });

  final double minTop;
  final double maxTop;
  final double horizonTop;

  double topFor({
    required ArInfoObject object,
    double? devicePitchDegrees,
    bool trackingLimited = false,
    double? targetAltitudeMeters,
    double? userAltitudeMeters,
  }) {
    final distance =
        object.distanceMeters ?? object.warning.distanceMeters.toDouble();
    final pitchOffset = _pitchOffset(devicePitchDegrees, trackingLimited);
    final baseY = (horizonTop + pitchOffset).clamp(minTop, maxTop).toDouble();
    final altitudeOffset = _reliableAltitudeOffset(
      distanceMeters: distance,
      targetAltitudeMeters: targetAltitudeMeters,
      userAltitudeMeters: userAltitudeMeters,
      trackingLimited: trackingLimited,
    );
    if (altitudeOffset != null) {
      return (baseY + altitudeOffset).clamp(minTop, maxTop).toDouble();
    }

    final distanceOffset = _distanceOffset(distance, object.type);
    final movementScale = trackingLimited ? 0.45 : 1.0;
    return (baseY + (distanceOffset * movementScale))
        .clamp(minTop, maxTop)
        .toDouble();
  }

  double _pitchOffset(double? pitchDegrees, bool trackingLimited) {
    if (pitchDegrees == null || !pitchDegrees.isFinite) return 0;
    final clampedPitch = pitchDegrees.clamp(-18, 18).toDouble();
    final scale = trackingLimited ? 0.0018 : 0.0032;
    return clampedPitch * scale;
  }

  double? _reliableAltitudeOffset({
    required double distanceMeters,
    required double? targetAltitudeMeters,
    required double? userAltitudeMeters,
    required bool trackingLimited,
  }) {
    if (targetAltitudeMeters == null || userAltitudeMeters == null) return null;
    if (!targetAltitudeMeters.isFinite || !userAltitudeMeters.isFinite) {
      return null;
    }

    final distance = distanceMeters.clamp(25, 2500).toDouble();
    final altitudeDelta = (targetAltitudeMeters - userAltitudeMeters).clamp(
      -35,
      35,
    );
    final perspective = (altitudeDelta / distance).clamp(-0.08, 0.08);
    final movementScale = trackingLimited ? 0.35 : 0.75;
    // A higher target should appear slightly higher on screen, which means a
    // smaller normalized top value. Missing altitude deliberately returns null
    // so remote geo objects stay close to the visual horizon.
    return -perspective * movementScale;
  }

  double _distanceOffset(double distanceMeters, WarningType type) {
    final distance = distanceMeters.clamp(0, 3000).toDouble();
    if (distance >= 1200) return 0;
    final nearbyFactor = (1200 - distance) / 1200;
    final typeBias = switch (type) {
      WarningType.speedCamera => 0.055,
      WarningType.chargingStation => 0.04,
      WarningType.speedLimit => 0.035,
      WarningType.roadwork => 0.03,
      WarningType.weather || WarningType.notice => 0.02,
    };
    return nearbyFactor * typeBias;
  }
}
