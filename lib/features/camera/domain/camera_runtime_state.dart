import 'package:camera/camera.dart';

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
    this.supportsUltraWide = false,
    this.currentZoomMode = CameraZoomMode.normal,
    this.lensType = CameraLensType.unknown,
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
    required bool supportsUltraWide,
    CameraZoomMode currentZoomMode = CameraZoomMode.normal,
    CameraLensType lensType = CameraLensType.unknown,
    bool isSwitchingZoom = false,
  }) : this._(
          CameraRuntimeAvailability.ready,
          cameraAvailable: true,
          cameraPermissionState: SensorPermissionState.granted,
          currentZoomLevel: currentZoomLevel,
          minZoom: minZoom,
          maxZoom: maxZoom,
          supportsUltraWide: supportsUltraWide,
          currentZoomMode: currentZoomMode,
          lensType: lensType,
          isSwitchingZoom: isSwitchingZoom,
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
  final bool supportsUltraWide;
  final CameraZoomMode currentZoomMode;
  final CameraLensType lensType;

  bool get shouldUseFallback =>
      availability != CameraRuntimeAvailability.ready &&
      availability != CameraRuntimeAvailability.initializing;

  String get currentZoomLabel => switch (currentZoomMode) {
        CameraZoomMode.ultraWide => '0.5x',
        CameraZoomMode.normal => '1x',
      };

  CameraRuntimeState copyWithZoom({
    required double currentZoomLevel,
    bool? isSwitchingZoom,
    CameraZoomMode? currentZoomMode,
    CameraLensType? lensType,
  }) {
    return CameraRuntimeState.ready(
      currentZoomLevel: currentZoomLevel,
      minZoom: minZoom ?? CameraZoomProfile.normal,
      maxZoom: maxZoom ?? CameraZoomProfile.normal,
      supportsUltraWide: supportsUltraWide,
      currentZoomMode: currentZoomMode ?? this.currentZoomMode,
      lensType: lensType ?? this.lensType,
      isSwitchingZoom: isSwitchingZoom ?? this.isSwitchingZoom,
    );
  }
}

class CameraZoomProfile {
  const CameraZoomProfile({
    required this.minZoom,
    required this.maxZoom,
    required this.defaultZoom,
    required this.defaultZoomMode,
    required this.supportsUltraWide,
  });

  static const ultraWide = 0.5;
  static const normal = 1.0;

  final double minZoom;
  final double maxZoom;
  final double defaultZoom;
  final CameraZoomMode defaultZoomMode;
  final bool supportsUltraWide;

  static CameraZoomProfile fromBounds({
    required double minZoom,
    required double maxZoom,
    bool hasUltraWideLens = false,
    bool preferUltraWide = true,
  }) {
    final safeMin = minZoom <= maxZoom ? minZoom : maxZoom;
    final safeMax = maxZoom >= minZoom ? maxZoom : minZoom;
    final supportsUltraWideZoom = safeMin <= ultraWide;
    final supportsUltraWide = hasUltraWideLens || supportsUltraWideZoom;
    final useUltraWide = preferUltraWide && supportsUltraWide;
    final defaultZoom = useUltraWide
        ? (hasUltraWideLens
            ? clamp(normal, safeMin, safeMax)
            : clamp(ultraWide, safeMin, safeMax))
        : clamp(normal, safeMin, safeMax);

    return CameraZoomProfile(
      minZoom: safeMin,
      maxZoom: safeMax,
      defaultZoom: defaultZoom,
      defaultZoomMode:
          useUltraWide ? CameraZoomMode.ultraWide : CameraZoomMode.normal,
      supportsUltraWide: supportsUltraWide,
    );
  }

  static double clamp(double requestedZoom, double minZoom, double maxZoom) {
    return requestedZoom.clamp(minZoom, maxZoom).toDouble();
  }

  double zoomForMode(CameraZoomMode mode, {required bool usesUltraWideLens}) {
    return switch (mode) {
      CameraZoomMode.ultraWide => usesUltraWideLens
          ? clamp(normal, minZoom, maxZoom)
          : clamp(ultraWide, minZoom, maxZoom),
      CameraZoomMode.normal => clamp(normal, minZoom, maxZoom),
    };
  }

  CameraZoomMode toggledMode(CameraZoomMode currentMode) {
    return currentMode == CameraZoomMode.ultraWide
        ? CameraZoomMode.normal
        : CameraZoomMode.ultraWide;
  }
}
