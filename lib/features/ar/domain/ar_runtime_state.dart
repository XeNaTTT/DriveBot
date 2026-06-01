enum ArPermissionState { unknown, granted, denied, unavailable }

enum ArTrackingQuality { unknown, stable, limited, unavailable }

final class ArRuntimeState {
  const ArRuntimeState({
    required this.isSupported,
    required this.isAvailable,
    required this.isRunning,
    required this.permissionState,
    required this.trackingQuality,
    this.errorMessage,
    this.fallbackReason,
    this.devicePitchDegrees,
  });

  const ArRuntimeState.initial()
    : this(
        isSupported: false,
        isAvailable: false,
        isRunning: false,
        permissionState: ArPermissionState.unknown,
        trackingQuality: ArTrackingQuality.unknown,
        fallbackReason: 'Kamera-Fallback',
      );

  const ArRuntimeState.fallback(String reason)
    : this(
        isSupported: false,
        isAvailable: false,
        isRunning: false,
        permissionState: ArPermissionState.unavailable,
        trackingQuality: ArTrackingQuality.unavailable,
        fallbackReason: reason,
      );

  const ArRuntimeState.available({bool isRunning = false})
    : this(
        isSupported: true,
        isAvailable: true,
        isRunning: isRunning,
        permissionState: ArPermissionState.granted,
        trackingQuality: isRunning
            ? ArTrackingQuality.stable
            : ArTrackingQuality.unknown,
      );

  final bool isSupported;
  final bool isAvailable;
  final bool isRunning;
  final ArPermissionState permissionState;
  final ArTrackingQuality trackingQuality;
  final String? errorMessage;
  final String? fallbackReason;
  final double? devicePitchDegrees;

  bool get shouldUseArKit => isSupported && isAvailable && !hasError;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  String get germanStatusLabel {
    if (hasError || !isSupported || !isAvailable) {
      return fallbackReason ?? 'AR nicht verfügbar';
    }
    if (trackingQuality == ArTrackingQuality.limited) {
      return 'Tracking eingeschränkt';
    }
    if (isRunning) return 'AR aktiv';
    return 'Tracking stabil';
  }

  ArRuntimeState copyWith({
    bool? isSupported,
    bool? isAvailable,
    bool? isRunning,
    ArPermissionState? permissionState,
    ArTrackingQuality? trackingQuality,
    String? errorMessage,
    String? fallbackReason,
    double? devicePitchDegrees,
  }) => ArRuntimeState(
    isSupported: isSupported ?? this.isSupported,
    isAvailable: isAvailable ?? this.isAvailable,
    isRunning: isRunning ?? this.isRunning,
    permissionState: permissionState ?? this.permissionState,
    trackingQuality: trackingQuality ?? this.trackingQuality,
    errorMessage: errorMessage ?? this.errorMessage,
    fallbackReason: fallbackReason ?? this.fallbackReason,
    devicePitchDegrees: devicePitchDegrees ?? this.devicePitchDegrees,
  );

  static ArRuntimeState fromNativeMap(Map<Object?, Object?> map) {
    final supported = map['isSupported'] == true;
    final running = map['isRunning'] == true;
    final quality = switch (map['trackingQuality']) {
      'stable' => ArTrackingQuality.stable,
      'limited' => ArTrackingQuality.limited,
      'unavailable' => ArTrackingQuality.unavailable,
      _ => ArTrackingQuality.unknown,
    };
    final error = map['errorMessage'] as String?;
    final fallback = map['fallbackReason'] as String?;
    final pitchValue = map['devicePitchDegrees'];
    final pitch = pitchValue is num ? pitchValue.toDouble() : null;
    return ArRuntimeState(
      isSupported: supported,
      isAvailable: supported && error == null,
      isRunning: running,
      permissionState: supported
          ? ArPermissionState.granted
          : ArPermissionState.unavailable,
      trackingQuality: quality,
      errorMessage: error,
      fallbackReason: fallback,
      devicePitchDegrees: pitch,
    );
  }
}
