import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

import '../domain/location_repository.dart';
import '../domain/location_status.dart';
import '../domain/permission_repository.dart';
import '../domain/sensor_permission_status.dart';
import 'mock_location_repository.dart';

class IosLocationRuntime implements LocationRepository, PermissionRepository {
  static const MethodChannel _cameraPermissionChannel = MethodChannel(
    'drivebot/camera_permission',
  );
  IosLocationRuntime({
    LocationRepository? mockLocationRepository,
  }) : _mockLocationRepository =
            mockLocationRepository ?? MockLocationRepository() {
    _initialize();
  }

  final LocationRepository _mockLocationRepository;

  final ValueNotifier<LocationStatus> _locationStatus = ValueNotifier(
    const LocationStatus(
      speedKph: 84,
      headingDegrees: 58,
      gpsFixStatus: GpsFixStatus.unavailable,
      isMock: true,
      isSpeedEstimatedFromGps: false,
    ),
  );
  final ValueNotifier<SensorPermissionStatus> _permissionStatus = ValueNotifier(
    const SensorPermissionStatus(
      camera: SensorPermissionState.denied,
      location: SensorPermissionState.denied,
      motion: SensorPermissionState.unavailable,
    ),
  );

  StreamSubscription<Position>? _positionSubscription;

  @override
  ValueListenable<LocationStatus> get locationStatusListenable =>
      _locationStatus;

  @override
  ValueListenable<SensorPermissionStatus> get permissionStatusListenable =>
      _permissionStatus;

  Future<void> _initialize() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _permissionStatus.value = _permissionStatus.value.copyWith(
        location: SensorPermissionState.unavailable,
      );
      _locationStatus.value =
          _mockLocationRepository.locationStatusListenable.value.copyWith(
        gpsFixStatus: GpsFixStatus.unavailable,
        isMock: true,
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final locationPermission = _mapLocationPermission(permission);

    final cameraPermission = await _requestCameraPermission();

    _permissionStatus.value = SensorPermissionStatus(
      camera: cameraPermission,
      location: locationPermission,
      motion: SensorPermissionState.unavailable,
    );

    if (locationPermission != SensorPermissionState.granted) {
      _locationStatus.value =
          _mockLocationRepository.locationStatusListenable.value.copyWith(
        gpsFixStatus: GpsFixStatus.unavailable,
        isMock: true,
      );
      return;
    }

    final current = await Geolocator.getCurrentPosition();
    _locationStatus.value = mapPositionToLocationStatus(
      position: current,
      fallback: _mockLocationRepository.locationStatusListenable.value,
    );

    _positionSubscription = Geolocator.getPositionStream().listen((position) {
      _locationStatus.value = mapPositionToLocationStatus(
        position: position,
        fallback: _mockLocationRepository.locationStatusListenable.value,
      );
    });
  }

  static SensorPermissionState _mapLocationPermission(
      LocationPermission permission) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        SensorPermissionState.granted,
      LocationPermission.denied => SensorPermissionState.denied,
      LocationPermission.deniedForever =>
        SensorPermissionState.permanentlyDenied,
      LocationPermission.unableToDetermine => SensorPermissionState.unavailable,
    };
  }

  Future<SensorPermissionState> _requestCameraPermission() async {
    try {
      final result =
          await _cameraPermissionChannel.invokeMethod<String>('request');
      return switch (result) {
        'granted' => SensorPermissionState.granted,
        'permanentlyDenied' => SensorPermissionState.permanentlyDenied,
        'denied' => SensorPermissionState.denied,
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
  }) {
    final hasValidSpeed = position.speed.isFinite && position.speed >= 0;
    final hasValidHeading = position.heading.isFinite && position.heading >= 0;
    final speedKph =
        hasValidSpeed ? (position.speed * 3.6).round() : fallback.speedKph;
    final heading =
        hasValidHeading ? position.heading.round() : fallback.headingDegrees;

    return LocationStatus(
      speedKph: speedKph,
      headingDegrees: heading,
      gpsFixStatus: _fixFromAccuracy(position.accuracy),
      isMock: !(hasValidSpeed && hasValidHeading),
      isSpeedEstimatedFromGps: hasValidSpeed,
    );
  }

  @visibleForTesting
  static GpsFixStatus fixFromAccuracy(double accuracyMeters) =>
      _fixFromAccuracy(accuracyMeters);

  static GpsFixStatus _fixFromAccuracy(double accuracyMeters) {
    if (accuracyMeters <= 12) return GpsFixStatus.strong;
    if (accuracyMeters <= 35) return GpsFixStatus.moderate;
    if (accuracyMeters <= 80) return GpsFixStatus.weak;
    return GpsFixStatus.unavailable;
  }

  void dispose() {
    _positionSubscription?.cancel();
  }
}

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

extension on LocationStatus {
  LocationStatus copyWith({
    int? speedKph,
    int? headingDegrees,
    GpsFixStatus? gpsFixStatus,
    bool? isMock,
    bool? isSpeedEstimatedFromGps,
  }) {
    return LocationStatus(
      speedKph: speedKph ?? this.speedKph,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      gpsFixStatus: gpsFixStatus ?? this.gpsFixStatus,
      isMock: isMock ?? this.isMock,
      isSpeedEstimatedFromGps:
          isSpeedEstimatedFromGps ?? this.isSpeedEstimatedFromGps,
    );
  }
}
