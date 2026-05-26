import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/location_repository.dart';
import '../domain/location_status.dart';
import '../domain/permission_repository.dart';
import '../domain/sensor_permission_status.dart';
import 'mock_location_repository.dart';
import 'mock_permission_repository.dart';

class IosLocationRuntime implements LocationRepository, PermissionRepository {
  IosLocationRuntime({
    LocationRepository? mockLocationRepository,
    PermissionRepository? mockPermissionRepository,
  }) : _mockLocationRepository = mockLocationRepository ?? MockLocationRepository(),
       _mockPermissionRepository =
           mockPermissionRepository ?? MockPermissionRepository() {
    _initialize();
  }

  final LocationRepository _mockLocationRepository;
  final PermissionRepository _mockPermissionRepository;

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
  ValueListenable<LocationStatus> get locationStatusListenable => _locationStatus;

  @override
  ValueListenable<SensorPermissionStatus> get permissionStatusListenable => _permissionStatus;

  Future<void> _initialize() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _permissionStatus.value = _permissionStatus.value.copyWith(
        location: SensorPermissionState.unavailable,
      );
      _locationStatus.value = _mockLocationRepository.locationStatusListenable.value.copyWith(
        gpsFixStatus: GpsFixStatus.unavailable,
        isMock: true,
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final locationPermission = switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse =>
        SensorPermissionState.granted,
      LocationPermission.denied => SensorPermissionState.denied,
      LocationPermission.deniedForever => SensorPermissionState.permanentlyDenied,
      LocationPermission.unableToDetermine => SensorPermissionState.unavailable,
    };

    _permissionStatus.value = SensorPermissionStatus(
      camera: SensorPermissionState.granted,
      location: locationPermission,
      motion: SensorPermissionState.unavailable,
    );

    if (locationPermission != SensorPermissionState.granted) {
      _locationStatus.value = _mockLocationRepository.locationStatusListenable.value.copyWith(
        gpsFixStatus: GpsFixStatus.unavailable,
      );
      return;
    }

    final current = await Geolocator.getCurrentPosition();
    _locationStatus.value = _fromPosition(current);

    _positionSubscription = Geolocator.getPositionStream().listen((position) {
      _locationStatus.value = _fromPosition(position);
    });
  }

  LocationStatus _fromPosition(Position position) {
    final fallback = _mockLocationRepository.locationStatusListenable.value;
    final speedKph = position.speed >= 0 ? (position.speed * 3.6).round() : fallback.speedKph;
    final heading = position.heading >= 0 ? position.heading.round() : fallback.headingDegrees;
    return LocationStatus(
      speedKph: speedKph,
      headingDegrees: heading,
      gpsFixStatus: _fixFromAccuracy(position.accuracy),
      isMock: false,
      isSpeedEstimatedFromGps: position.speed >= 0,
    );
  }

  GpsFixStatus _fixFromAccuracy(double accuracyMeters) {
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
