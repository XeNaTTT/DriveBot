class WarningRequest {
  const WarningRequest({
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
  });

  const WarningRequest.fallback()
    : latitude = 52.5200,
      longitude = 13.4050,
      headingDegrees = 0;

  final double latitude;
  final double longitude;
  final int headingDegrees;

  String get cacheKey =>
      '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
}
