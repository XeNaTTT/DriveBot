enum SpeedCameraReportConfidence {
  high('high'),
  medium('medium'),
  low('low');

  const SpeedCameraReportConfidence(this.storageValue);

  final String storageValue;

  static SpeedCameraReportConfidence fromStorageValue(String? value) =>
      switch (value) {
        'high' => high,
        'medium' => medium,
        _ => low,
      };
}
