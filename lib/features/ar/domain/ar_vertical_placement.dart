import 'ar_info_object.dart';
import 'ar_runtime_state.dart';
import 'horizon_projection_model.dart';

final class ArVerticalPlacement {
  const ArVerticalPlacement({
    this.minTop = 0.20,
    this.maxTop = 0.68,
    this.horizonModel = const HorizonProjectionModel(),
  });

  final double minTop;
  final double maxTop;
  final HorizonProjectionModel horizonModel;

  double topFor({
    required ArInfoObject object,
    double? devicePitchDegrees,
    bool trackingLimited = false,
    double? deviceRollDegrees,
    double? targetAltitudeMeters,
    double? userAltitudeMeters,
    double screenHeight = 1000,
    double safeAreaTop = 0,
    double safeAreaBottom = 0,
  }) {
    final distance =
        object.distanceMeters ?? object.warning.distanceMeters.toDouble();
    final trackingQuality = trackingLimited
        ? ArTrackingQuality.limited
        : ArTrackingQuality.stable;
    final baseY = horizonModel.markerTopFraction(
      screenHeight: screenHeight,
      safeAreaTop: safeAreaTop,
      safeAreaBottom: safeAreaBottom,
      distanceMeters: distance,
      type: object.type,
      devicePitchDegrees: devicePitchDegrees,
      deviceRollDegrees: deviceRollDegrees,
      trackingQuality: trackingQuality,
    );
    final altitudeOffset = _reliableAltitudeOffset(
      distanceMeters: distance,
      targetAltitudeMeters: targetAltitudeMeters,
      userAltitudeMeters: userAltitudeMeters,
      trackingLimited: trackingLimited,
    );
    if (altitudeOffset != null) {
      return (baseY + altitudeOffset).clamp(minTop, maxTop).toDouble();
    }

    return baseY.clamp(minTop, maxTop).toDouble();
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
}
