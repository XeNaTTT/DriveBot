class HeadingUtils {
  const HeadingUtils._();

  static int? normalizeHeading(double? degrees) {
    if (degrees == null || !degrees.isFinite) return null;
    final normalized = degrees % 360;
    final positive = normalized < 0 ? normalized + 360 : normalized;
    return positive.round() % 360;
  }

  static String cardinalDirection(int degrees) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final normalized = normalizeHeading(degrees.toDouble()) ?? 0;
    final index = (normalized / 45).round() % dirs.length;
    return dirs[index];
  }

  static int fallbackAwareHeading({
    required double? compassHeading,
    required double? gpsCourse,
    required int fallbackHeading,
  }) {
    return normalizeHeading(compassHeading) ??
        normalizeHeading(gpsCourse) ??
        normalizeHeading(fallbackHeading.toDouble()) ??
        0;
  }
}
