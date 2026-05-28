import 'dart:async';

import 'package:driveassistant_ar/features/location/data/ios_location_runtime.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:driveassistant_ar/features/location/domain/sensor_permission_status.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  const fallback = LocationStatus(
    speedKph: 84,
    headingDegrees: 58,
    gpsFixStatus: GpsFixStatus.unavailable,
    isMock: true,
    isSpeedEstimatedFromGps: false,
  );

  test('invalid speed uses stationary value safely', () {
    final status = IosLocationRuntime.mapPositionToLocationStatus(
      position: _position(speed: -1, heading: 120, accuracy: 10),
      fallback: fallback,
    );

    expect(status.speedKph, 0);
    expect(status.headingDegrees, 120);
    expect(status.isHeadingFromGps, isTrue);
  });

  test('location service unavailable maps to unavailable gps fix', () {
    expect(IosLocationRuntime.fixFromAccuracy(120), GpsFixStatus.unavailable);
  });

  test('real speed and compass heading become live sensor mode', () {
    final status = IosLocationRuntime.mapPositionToLocationStatus(
      position: _position(speed: 20, heading: 270, accuracy: 8),
      fallback: fallback,
      compassHeadingDegrees: -5,
    );

    expect(status.speedKph, 72);
    expect(status.headingDegrees, 355);
    expect(status.isMock, isFalse);
    expect(status.isSpeedEstimatedFromGps, isTrue);
    expect(status.isHeadingFromCompass, isTrue);
  });

  test('permission denied fallback is safe', () async {
    final runtime = IosLocationRuntime(
      isLocationServiceEnabled: () async => true,
      checkLocationPermission: () async => LocationPermission.denied,
      requestLocationPermission: () async => LocationPermission.denied,
      getCurrentPosition: () async =>
          _position(speed: 10, heading: 10, accuracy: 8),
      getPositionStream: () => const Stream.empty(),
      getCompassStream: () => const Stream<CompassEvent>.empty(),
      getMotionStream: () => const Stream<AccelerometerEvent>.empty(),
      loadCameraDescriptions: () async => const [],
    );

    await _settleAsync();

    expect(runtime.permissionStatusListenable.value.location,
        SensorPermissionState.denied);
    expect(runtime.locationStatusListenable.value.gpsFixStatus,
        GpsFixStatus.denied);
    expect(runtime.locationStatusListenable.value.isMock, isTrue);
    runtime.dispose();
  });

  test('permission permanently denied fallback is safe', () async {
    final runtime = IosLocationRuntime(
      isLocationServiceEnabled: () async => true,
      checkLocationPermission: () async => LocationPermission.deniedForever,
      requestLocationPermission: () async => LocationPermission.deniedForever,
      getCurrentPosition: () async =>
          _position(speed: 10, heading: 10, accuracy: 8),
      getPositionStream: () => const Stream.empty(),
      getCompassStream: () => const Stream<CompassEvent>.empty(),
      getMotionStream: () => const Stream<AccelerometerEvent>.empty(),
      loadCameraDescriptions: () async => const [],
    );

    await _settleAsync();

    expect(runtime.permissionStatusListenable.value.location,
        SensorPermissionState.permanentlyDenied);
    expect(runtime.locationStatusListenable.value.gpsFixStatus,
        GpsFixStatus.denied);
    expect(runtime.locationStatusListenable.value.isMock, isTrue);
    runtime.dispose();
  });

  test('location service disabled fallback is safe', () async {
    final runtime = IosLocationRuntime(
      isLocationServiceEnabled: () async => false,
      checkLocationPermission: () async => LocationPermission.whileInUse,
      requestLocationPermission: () async => LocationPermission.whileInUse,
      getCurrentPosition: () async =>
          _position(speed: 10, heading: 10, accuracy: 8),
      getPositionStream: () => const Stream.empty(),
      getCompassStream: () => const Stream<CompassEvent>.empty(),
      getMotionStream: () => const Stream<AccelerometerEvent>.empty(),
      loadCameraDescriptions: () async => const [],
    );

    await _settleAsync();

    expect(runtime.permissionStatusListenable.value.location,
        SensorPermissionState.unavailable);
    expect(runtime.locationStatusListenable.value.gpsFixStatus,
        GpsFixStatus.unavailable);
    expect(runtime.locationStatusListenable.value.isMock, isTrue);
    runtime.dispose();
  });

  test('null position fallback is safe', () async {
    final runtime = IosLocationRuntime(
      isLocationServiceEnabled: () async => true,
      checkLocationPermission: () async => LocationPermission.whileInUse,
      requestLocationPermission: () async => LocationPermission.whileInUse,
      getCurrentPosition: () =>
          Future.error(StateError('position unavailable')),
      getPositionStream: () => const Stream.empty(),
      getCompassStream: () => const Stream<CompassEvent>.empty(),
      getMotionStream: () => const Stream<AccelerometerEvent>.empty(),
      loadCameraDescriptions: () async => const [],
    );

    await _settleAsync();

    expect(runtime.permissionStatusListenable.value.location,
        SensorPermissionState.granted);
    expect(runtime.locationStatusListenable.value.gpsFixStatus,
        GpsFixStatus.unavailable);
    expect(runtime.locationStatusListenable.value.isMock, isTrue);
    runtime.dispose();
  });
}

Future<void> _settleAsync() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

Position _position({
  required double speed,
  required double heading,
  required double accuracy,
}) {
  return Position(
    longitude: 10,
    latitude: 10,
    timestamp: DateTime(2026),
    accuracy: accuracy,
    altitude: 1,
    altitudeAccuracy: 1,
    heading: heading,
    headingAccuracy: 1,
    speed: speed,
    speedAccuracy: 1,
  );
}
