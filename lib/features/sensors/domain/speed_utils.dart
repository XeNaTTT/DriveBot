class SpeedUtils {
  const SpeedUtils._();

  static const double metersPerSecondToKilometersPerHour = 3.6;
  static const int maximumSafeRoadSpeedKph = 260;

  static int speedKphFromMetersPerSecond(double? metersPerSecond) {
    if (metersPerSecond == null ||
        !metersPerSecond.isFinite ||
        metersPerSecond < 0) {
      return 0;
    }

    final speed =
        (metersPerSecond * metersPerSecondToKilometersPerHour).round();
    if (speed > maximumSafeRoadSpeedKph) return maximumSafeRoadSpeedKph;
    return speed;
  }

  static int fallbackAwareSpeedKph({
    required double? metersPerSecond,
    required int fallbackSpeedKph,
  }) {
    final speed = speedKphFromMetersPerSecond(metersPerSecond);
    if (speed == 0 && (metersPerSecond == null || metersPerSecond < 0)) {
      return fallbackSpeedKph;
    }
    return speed;
  }
}
