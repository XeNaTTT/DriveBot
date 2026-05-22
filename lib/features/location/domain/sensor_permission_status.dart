enum SensorPermissionState { granted, denied, permanentlyDenied, unavailable }

class SensorPermissionStatus {
  const SensorPermissionStatus({
    required this.camera,
    required this.location,
    required this.motion,
  });

  final SensorPermissionState camera;
  final SensorPermissionState location;
  final SensorPermissionState motion;

  bool get allGranted =>
      camera == SensorPermissionState.granted &&
      location == SensorPermissionState.granted &&
      motion == SensorPermissionState.granted;

  bool get hasCriticalDenial =>
      location == SensorPermissionState.denied ||
      location == SensorPermissionState.permanentlyDenied ||
      camera == SensorPermissionState.permanentlyDenied ||
      motion == SensorPermissionState.permanentlyDenied;
}
