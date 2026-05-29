import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../sensors/domain/heading_utils.dart';
import '../../sensors/domain/sensor_runtime_state.dart';
import '../../sensors/domain/speed_utils.dart';
import '../domain/location_repository.dart';
import '../domain/location_status.dart';
import '../domain/permission_repository.dart';
import '../domain/sensor_permission_status.dart';
import 'mock_location_repository.dart';

typedef LocationServiceEnabledChecker = Future<bool> Function();
typedef LocationPermissionChecker = Future<LocationPermission> Function();
typedef LocationPermissionRequester = Future<LocationPermission> Function();
typedef CurrentPositionLoader = Future<Position> Function();
typedef PositionStreamLoader = Stream<Position> Function();
typedef CompassStreamLoader = Stream<CompassEvent>? Function();
typedef MotionStreamLoader = Stream<AccelerometerEvent> Function();
typedef CameraDescriptionsLoader = Future<List<CameraDescription>> Function();

class IosLocationRuntime implements LocationRepository, PermissionRepository {
  IosLocationRuntime({
    LocationRepository? mockLocationRepository,
    this.isLocationServiceEnabled = Geolocator.isLocationServiceEnabled,
    this.checkLocationPermission = Geolocator.checkPermission,
    this.requestLocationPermission = Geolocator.requestPermission,
    this.getCurrentPosition = _defaultGetCurrentPosition,
    this.getPositionStream = _defaultGetPositionStream,
    this.getCompassStream = _defaultGetCompassStream,
    this.getMotionStream = _defaultGetMotionStream,
    this.loadCameraDescriptions = availableCameras,
  }) : _mockLocationRepository =
           mockLocationRepository ?? MockLocationRepository() {
    _initialize();
  }

  final LocationRepository _mockLocationRepository;
  final LocationServiceEnabledChecker isLocationServiceEnabled;
  final LocationPermissionChecker checkLocationPermission;
  final LocationPermissionRequester requestLocationPermission;
  final CurrentPositionLoader getCurrentPosition;
  final PositionStreamLoader getPositionStream;
  final CompassStreamLoader getCompassStream;
  final MotionStreamLoader getMotionStream;
  final CameraDescriptionsLoader loadCameraDescriptions;

  final ValueNotifier<LocationStatus> _locationStatus = ValueNotifier(
    const LocationStatus(
      speedKph: 84,
      headingDegrees: 58,
      gpsFixStatus: GpsFixStatus.unavailable,
      isMock: true,
      isSpeedEstimatedFromGps: false,
      latitude: 50.1109,
      longitude: 8.6821,
    ),
  );
  final ValueNotifier<SensorPermissionStatus> _permissionStatus = ValueNotifier(
    const SensorPermissionStatus(
      camera: SensorPermissionState.denied,
      location: SensorPermissionState.denied,
      motion: SensorPermissionState.unavailable,
    ),
  );
  final ValueNotifier<MotionRuntimeState> _motionStatus = ValueNotifier(
    const MotionRuntimeState.unavailable(),
  );

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _motionSubscription;
  Position? _lastPosition;
  int? _lastCompassHeading;

  @override
  ValueListenable<LocationStatus> get locationStatusListenable =>
      _locationStatus;

  @override
  ValueListenable<SensorPermissionStatus> get permissionStatusListenable =>
      _permissionStatus;

  ValueListenable<MotionRuntimeState> get motionStatusListenable =>
      _motionStatus;

  Future<void> _initialize() async {
    await _initializeCameraAndMotionState();

    final serviceEnabled = await _safeLocationServiceEnabled();
    if (!serviceEnabled) {
      _setLocationFallback(
        GpsFixStatus.unavailable,
        SensorPermissionState.unavailable,
      );
      return;
    }

    final locationPermission = await _resolveLocationPermission();
    _permissionStatus.value = _permissionStatus.value.copyWith(
      location: locationPermission,
    );

    if (locationPermission != SensorPermissionState.granted) {
      _setLocationFallback(GpsFixStatus.denied, locationPermission);
      return;
    }

    _subscribeToCompass();
    await _loadCurrentPosition();
    _subscribeToPositions();
  }

  Future<void> _initializeCameraAndMotionState() async {
    final cameraPermission = await _requestCameraPermission();
    _permissionStatus.value = _permissionStatus.value.copyWith(
      camera: cameraPermission,
    );
    _subscribeToMotion();
  }

  Future<bool> _safeLocationServiceEnabled() async {
    try {
      return await isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<SensorPermissionState> _resolveLocationPermission() async {
    try {
      var permission = await checkLocationPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestLocationPermission();
      }
      return mapLocationPermission(permission);
    } catch (_) {
      return SensorPermissionState.unavailable;
    }
  }

  void _setLocationFallback(
    GpsFixStatus gpsFixStatus,
    SensorPermissionState permission,
  ) {
    _permissionStatus.value = _permissionStatus.value.copyWith(
      location: permission,
    );
    _locationStatus.value = _mockLocationRepository
        .locationStatusListenable
        .value
        .copyWith(
          gpsFixStatus: gpsFixStatus,
          isMock: true,
          isSpeedEstimatedFromGps: false,
          isHeadingFromCompass: false,
          isHeadingFromGps: false,
        );
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final current = await getCurrentPosition();
      _applyPosition(current);
    } catch (_) {
      _setLocationFallback(
        GpsFixStatus.unavailable,
        SensorPermissionState.granted,
      );
    }
  }

  void _subscribeToPositions() {
    try {
      _positionSubscription = getPositionStream().listen(
        _applyPosition,
        onError: (_) => _setLocationFallback(
          GpsFixStatus.unavailable,
          SensorPermissionState.granted,
        ),
      );
    } catch (_) {
      _setLocationFallback(
        GpsFixStatus.unavailable,
        SensorPermissionState.granted,
      );
    }
  }

  void _subscribeToCompass() {
    try {
      final stream = getCompassStream();
      if (stream == null) return;
      _compassSubscription = stream.listen(
        (event) {
          _lastCompassHeading = HeadingUtils.normalizeHeading(
            event.headingForCameraMode ?? event.heading,
          );
          final position = _lastPosition;
          if (position != null) _applyPosition(position);
        },
        onError: (_) {
          _lastCompassHeading = null;
          final position = _lastPosition;
          if (position != null) _applyPosition(position);
        },
      );
    } catch (_) {
      _lastCompassHeading = null;
    }
  }

  void _subscribeToMotion() {
    try {
      _motionSubscription = getMotionStream().listen(
        (event) {
          _motionStatus.value = MotionRuntimeState(
            availability: MotionRuntimeAvailability.available,
            pitchDegrees: _radiansToDegrees(
              math.atan2(
                event.y,
                math.sqrt(event.x * event.x + event.z * event.z),
              ),
            ),
            rollDegrees: _radiansToDegrees(math.atan2(-event.x, event.z)),
          );
          _permissionStatus.value = _permissionStatus.value.copyWith(
            motion: SensorPermissionState.granted,
          );
        },
        onError: (_) {
          _motionStatus.value = const MotionRuntimeState(
            availability: MotionRuntimeAvailability.unavailable,
          );
          _permissionStatus.value = _permissionStatus.value.copyWith(
            motion: SensorPermissionState.unavailable,
          );
        },
      );
    } catch (_) {
      _motionStatus.value = const MotionRuntimeState(
        availability: MotionRuntimeAvailability.unavailable,
      );
      _permissionStatus.value = _permissionStatus.value.copyWith(
        motion: SensorPermissionState.unavailable,
      );
    }
  }

  void _applyPosition(Position position) {
    _lastPosition = position;
    _locationStatus.value = mapPositionToLocationStatus(
      position: position,
      fallback: _mockLocationRepository.locationStatusListenable.value,
      compassHeadingDegrees: _lastCompassHeading?.toDouble(),
    );
  }

  static double _radiansToDegrees(double radians) => radians * 180 / math.pi;

  @visibleForTesting
  static SensorPermissionState mapLocationPermission(
    LocationPermission permission,
  ) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => SensorPermissionState.granted,
      LocationPermission.denied => SensorPermissionState.denied,
      LocationPermission.deniedForever =>
        SensorPermissionState.permanentlyDenied,
      LocationPermission.unableToDetermine => SensorPermissionState.unavailable,
    };
  }

  Future<SensorPermissionState> _requestCameraPermission() async {
    try {
      final cameras = await loadCameraDescriptions();
      if (cameras.isEmpty) return SensorPermissionState.unavailable;

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.dispose();
      return SensorPermissionState.granted;
    } on CameraException catch (error) {
      return switch (error.code) {
        'CameraAccessDenied' => SensorPermissionState.denied,
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' => SensorPermissionState.permanentlyDenied,
        _ => SensorPermissionState.unavailable,
      };
    } catch (_) {
      return SensorPermissionState.unavailable;
    }
  }

  @visibleForTesting
  static LocationStatus mapPositionToLocationStatus({
    required Position position,
    required LocationStatus fallback,
    double? compassHeadingDegrees,
  }) {
    final speedKph = SpeedUtils.speedKphFromMetersPerSecond(position.speed);
    final hasValidSpeed =
        position.speed.isFinite && position.speed >= 0 && speedKph > 0;
    final compassHeading = HeadingUtils.normalizeHeading(compassHeadingDegrees);
    final gpsHeading = HeadingUtils.normalizeHeading(position.heading);
    final heading = compassHeading ?? gpsHeading ?? fallback.headingDegrees;
    final hasLiveHeading = compassHeading != null || gpsHeading != null;

    return LocationStatus(
      speedKph: speedKph,
      headingDegrees: heading,
      gpsFixStatus: _fixFromAccuracy(position.accuracy),
      isMock: !hasValidSpeed && !hasLiveHeading,
      isSpeedEstimatedFromGps: hasValidSpeed,
      isHeadingFromCompass: compassHeading != null,
      isHeadingFromGps: compassHeading == null && gpsHeading != null,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @visibleForTesting
  static LocationStatus fallbackStatus({
    required LocationStatus fallback,
    required GpsFixStatus gpsFixStatus,
  }) {
    return fallback.copyWith(
      gpsFixStatus: gpsFixStatus,
      isMock: true,
      isSpeedEstimatedFromGps: false,
      isHeadingFromCompass: false,
      isHeadingFromGps: false,
    );
  }

  @visibleForTesting
  static GpsFixStatus fixFromAccuracy(double accuracyMeters) =>
      _fixFromAccuracy(accuracyMeters);

  static GpsFixStatus _fixFromAccuracy(double accuracyMeters) {
    if (!accuracyMeters.isFinite || accuracyMeters < 0) {
      return GpsFixStatus.unavailable;
    }
    if (accuracyMeters <= 12) return GpsFixStatus.strong;
    if (accuracyMeters <= 35) return GpsFixStatus.moderate;
    if (accuracyMeters <= 80) return GpsFixStatus.weak;
    return GpsFixStatus.unavailable;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _motionSubscription?.cancel();
  }
}

Future<Position> _defaultGetCurrentPosition() {
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    ),
  );
}

Stream<Position> _defaultGetPositionStream() {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    ),
  );
}

Stream<CompassEvent>? _defaultGetCompassStream() => FlutterCompass.events;

Stream<AccelerometerEvent> _defaultGetMotionStream() =>
    accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval);

extension on SensorPermissionStatus {
  SensorPermissionStatus copyWith({
    SensorPermissionState? camera,
    SensorPermissionState? location,
    SensorPermissionState? motion,
  }) {
    return SensorPermissionStatus(
      camera: camera ?? this.camera,
      location: location ?? this.location,
      motion: motion ?? this.motion,
    );
  }
}
