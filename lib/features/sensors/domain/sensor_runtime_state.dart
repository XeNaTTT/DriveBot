import '../../location/domain/location_status.dart';
import '../../location/domain/sensor_permission_status.dart';

enum SensorRuntimeMode { liveAr, partialLive, fallback }

enum MotionRuntimeAvailability { available, denied, unsupported, unavailable }

class MotionRuntimeState {
  const MotionRuntimeState({
    required this.availability,
    this.pitchDegrees,
    this.rollDegrees,
  });

  const MotionRuntimeState.unavailable()
      : this(availability: MotionRuntimeAvailability.unavailable);

  final MotionRuntimeAvailability availability;
  final double? pitchDegrees;
  final double? rollDegrees;

  bool get isAvailable => availability == MotionRuntimeAvailability.available;
}

class SensorRuntimeState {
  const SensorRuntimeState({
    required this.cameraAvailable,
    required this.locationStatus,
    required this.permissionStatus,
    required this.motionStatus,
  });

  final bool cameraAvailable;
  final LocationStatus locationStatus;
  final SensorPermissionStatus permissionStatus;
  final MotionRuntimeState motionStatus;

  bool get locationAvailable =>
      locationStatus.hasLiveLocation && !locationStatus.isMock;
  bool get headingAvailable => locationStatus.hasLiveHeading;
  bool get motionAvailable => motionStatus.isAvailable;

  bool get isFullyLiveMode => mode == SensorRuntimeMode.liveAr;
  bool get isPartialLiveMode => mode == SensorRuntimeMode.partialLive;
  bool get isFallbackMode => mode == SensorRuntimeMode.fallback;

  SensorRuntimeMode get mode {
    if (cameraAvailable && locationAvailable && headingAvailable) {
      return SensorRuntimeMode.liveAr;
    }
    if (cameraAvailable || locationAvailable || headingAvailable) {
      return SensorRuntimeMode.partialLive;
    }
    return SensorRuntimeMode.fallback;
  }

  String get modeLabel => switch (mode) {
        SensorRuntimeMode.liveAr => 'Live-AR',
        SensorRuntimeMode.partialLive => 'Teilweise live',
        SensorRuntimeMode.fallback => 'Fallback',
      };

  List<String> get compactMessages {
    final messages = <String>[];
    messages.add(cameraAvailable ? 'Kamera aktiv' : 'Kamera nicht verfügbar');
    if (!locationAvailable) messages.add('Standort erforderlich');
    if (!headingAvailable) messages.add('Kompass nicht verfügbar');
    if (isFallbackMode) messages.add('Ersatzmodus');
    return messages;
  }
}
