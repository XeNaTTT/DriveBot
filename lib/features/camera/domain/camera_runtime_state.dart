enum CameraRuntimeAvailability {
  initializing,
  permissionDenied,
  unavailable,
  ready,
  failed,
}

class CameraRuntimeState {
  const CameraRuntimeState._(this.availability, {this.message});

  const CameraRuntimeState.initializing()
      : this._(CameraRuntimeAvailability.initializing);

  const CameraRuntimeState.permissionDenied()
      : this._(CameraRuntimeAvailability.permissionDenied);

  const CameraRuntimeState.unavailable([String? message])
      : this._(CameraRuntimeAvailability.unavailable, message: message);

  const CameraRuntimeState.ready() : this._(CameraRuntimeAvailability.ready);

  const CameraRuntimeState.failed([String? message])
      : this._(CameraRuntimeAvailability.failed, message: message);

  final CameraRuntimeAvailability availability;
  final String? message;

  bool get shouldUseFallback =>
      availability != CameraRuntimeAvailability.ready &&
      availability != CameraRuntimeAvailability.initializing;
}
