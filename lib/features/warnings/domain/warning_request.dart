class WarningRequest {
  const WarningRequest({
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
    this.hasCurrentLocation = true,
  });

  const WarningRequest.fallback()
    : latitude = 52.5200,
      longitude = 13.4050,
      headingDegrees = 0,
      hasCurrentLocation = false;

  final double latitude;
  final double longitude;
  final int headingDegrees;
  final bool hasCurrentLocation;

  String get cacheKey =>
      '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
}
