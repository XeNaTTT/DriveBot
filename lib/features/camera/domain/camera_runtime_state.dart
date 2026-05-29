import '../../location/domain/sensor_permission_status.dart';

enum CameraRuntimeAvailability {
  initializing,
  permissionDenied,
  unavailable,
  ready,
  failed,
}

enum CameraZoomMode { ultraWide, normal }

class CameraRuntimeState {
  const CameraRuntimeState._(
    this.availability, {
    required this.cameraAvailable,
    required this.cameraPermissionState,
    this.message,
    this.currentZoomLevel,
    this.minZoom,
    this.maxZoom,
    this.isSwitchingZoom = false,
    this.zoomMode = CameraZoomMode.normal,
    this.canSwitchLens = false,
  });

  const CameraRuntimeState.initializing()
    : this._(
        CameraRuntimeAvailability.initializing,
        cameraAvailable: false,
        cameraPermissionState: SensorPermissionState.unavailable,
      );

  const CameraRuntimeState.permissionDenied()
    : this._(
        CameraRuntimeAvailability.permissionDenied,
        cameraAvailable: false,
        cameraPermissionState: SensorPermissionState.denied,
      );

  const CameraRuntimeState.unavailable([String? message])
    : this._(
        CameraRuntimeAvailability.unavailable,
        cameraAvailable: false,
        cameraPermissionState: SensorPermissionState.granted,
        message: message,
      );

  const CameraRuntimeState.ready({
    required double currentZoomLevel,
    required double minZoom,
    required double maxZoom,
    bool isSwitchingZoom = false,
    CameraZoomMode zoomMode = CameraZoomMode.normal,
    bool canSwitchLens = false,
  }) : this._(
         CameraRuntimeAvailability.ready,
         cameraAvailable: true,
         cameraPermissionState: SensorPermissionState.granted,
         currentZoomLevel: currentZoomLevel,
         minZoom: minZoom,
         maxZoom: maxZoom,
         isSwitchingZoom: isSwitchingZoom,
         zoomMode: zoomMode,
         canSwitchLens: canSwitchLens,
       );

  const CameraRuntimeState.failed([String? message])
    : this._(
        CameraRuntimeAvailability.failed,
        cameraAvailable: false,
        cameraPermissionState: SensorPermissionState.granted,
        message: message,
      );

  final CameraRuntimeAvailability availability;
  final String? message;
  final SensorPermissionState cameraPermissionState;
  final bool cameraAvailable;
  final double? currentZoomLevel;
  final double? minZoom;
  final double? maxZoom;
  final bool isSwitchingZoom;
  final CameraZoomMode zoomMode;
  final bool canSwitchLens;

  bool get shouldUseFallback =>
      availability != CameraRuntimeAvailability.ready &&
      availability != CameraRuntimeAvailability.initializing;

  bool get supportsUltraWide =>
      canSwitchLens || (minZoom ?? 1) <= CameraZoomProfile.ultraWide;

  String get currentZoomLabel =>
      zoomMode == CameraZoomMode.ultraWide ||
          (currentZoomLevel ?? 1) < CameraZoomProfile.normal
      ? '0.5x'
      : '1x';

  CameraRuntimeState copyWithZoom({
    required double currentZoomLevel,
    bool? isSwitchingZoom,
    CameraZoomMode? zoomMode,
    bool? canSwitchLens,
  }) {
    return CameraRuntimeState.ready(
      currentZoomLevel: currentZoomLevel,
      minZoom: minZoom ?? CameraZoomProfile.normal,
      maxZoom: maxZoom ?? CameraZoomProfile.normal,
      isSwitchingZoom: isSwitchingZoom ?? this.isSwitchingZoom,
      zoomMode: zoomMode ?? this.zoomMode,
      canSwitchLens: canSwitchLens ?? this.canSwitchLens,
    );
  }
}

class CameraZoomProfile {
  const CameraZoomProfile({
    required this.minZoom,
    required this.maxZoom,
    required this.defaultZoom,
  });

  static const ultraWide = 0.5;
  static const normal = 1.0;

  final double minZoom;
  final double maxZoom;
  final double defaultZoom;

  bool get supportsUltraWide => minZoom <= ultraWide;

  static CameraZoomProfile fromBounds({
    required double minZoom,
    required double maxZoom,
  }) {
    final safeMin = minZoom <= maxZoom ? minZoom : maxZoom;
    final safeMax = maxZoom >= minZoom ? maxZoom : minZoom;
    final defaultZoom = safeMin <= ultraWide
        ? ultraWide
        : (safeMin <= normal && safeMax >= normal ? normal : safeMin);

    return CameraZoomProfile(
      minZoom: safeMin,
      maxZoom: safeMax,
      defaultZoom: clamp(defaultZoom, safeMin, safeMax),
    );
  }

  static double clamp(double requestedZoom, double minZoom, double maxZoom) {
    return requestedZoom.clamp(minZoom, maxZoom).toDouble();
  }

  double toggleTarget(double currentZoom) {
    final requested = currentZoom < normal ? normal : ultraWide;
    return clamp(requested, minZoom, maxZoom);
  }
}
