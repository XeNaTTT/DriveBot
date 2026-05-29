enum SpeedCameraReportType {
  mobile('mobile', 'Mobiler Blitzer'),
  fixed('fixed', 'Fester Blitzer');

  const SpeedCameraReportType(this.storageValue, this.germanLabel);

  final String storageValue;
  final String germanLabel;

  static SpeedCameraReportType fromStorageValue(String value) =>
      switch (value) {
        'fixed' => fixed,
        _ => mobile,
      };
}
