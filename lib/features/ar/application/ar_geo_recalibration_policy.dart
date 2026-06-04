import 'geo_ar_coordinate_mapper.dart';

final class ArGeoSessionOrigin {
  const ArGeoSessionOrigin({
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
    required this.trackingQualityLabel,
  });

  final double latitude;
  final double longitude;
  final double headingDegrees;
  final String trackingQualityLabel;
}

final class ArGeoRecalibrationPolicy {
  const ArGeoRecalibrationPolicy({
    this.movementThresholdMeters = 5,
    this.headingThresholdDegrees = 8,
    this.coordinateMapper = const GeoArCoordinateMapper(),
  });

  final double movementThresholdMeters;
  final double headingThresholdDegrees;
  final GeoArCoordinateMapper coordinateMapper;

  bool shouldRecalibrate({
    required ArGeoSessionOrigin? origin,
    required double latitude,
    required double longitude,
    required double headingDegrees,
    required String trackingQualityLabel,
  }) {
    if (origin == null) return true;
    if (origin.trackingQualityLabel != trackingQualityLabel) return true;

    final moved = coordinateMapper.distanceMeters(
      currentLatitude: origin.latitude,
      currentLongitude: origin.longitude,
      targetLatitude: latitude,
      targetLongitude: longitude,
    );
    if (moved > movementThresholdMeters) return true;

    final headingDelta = normalizedHeadingDeltaDegrees(
      previous: origin.headingDegrees,
      current: headingDegrees,
    ).abs();
    return headingDelta > headingThresholdDegrees;
  }

  double normalizedHeadingDeltaDegrees({
    required double previous,
    required double current,
  }) {
    var delta = (current - previous) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return delta;
  }
}
