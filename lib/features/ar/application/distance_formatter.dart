enum DistanceConfidence { unavailable, low, medium, high }

class DistanceFormatter {
  const DistanceFormatter({this.poorAccuracyThresholdMeters = 50});

  final double poorAccuracyThresholdMeters;

  String format({double? distanceMeters, double? accuracyMeters}) {
    if (distanceMeters == null || !distanceMeters.isFinite) {
      return 'Entfernung unbekannt';
    }

    final rounded = _roundedMeters(distanceMeters);
    if (rounded < 25) return 'in der Nähe';

    final label = rounded >= 1000
        ? '${(rounded / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
        : '$rounded m';
    return _isPoorAccuracy(accuracyMeters) ? 'ca. $label' : label;
  }

  DistanceConfidence confidenceFor(double? accuracyMeters) {
    if (accuracyMeters == null) return DistanceConfidence.unavailable;
    if (accuracyMeters <= 20) return DistanceConfidence.high;
    if (accuracyMeters <= poorAccuracyThresholdMeters) {
      return DistanceConfidence.medium;
    }
    return DistanceConfidence.low;
  }

  int _roundedMeters(double meters) {
    if (meters < 100) return _roundTo(meters, 5);
    if (meters < 500) return _roundTo(meters, 10);
    if (meters < 1000) return _roundTo(meters, 25);
    return _roundTo(meters, 100);
  }

  int _roundTo(double value, int step) => (value / step).round() * step;

  bool _isPoorAccuracy(double? accuracyMeters) =>
      accuracyMeters != null && accuracyMeters > poorAccuracyThresholdMeters;
}
