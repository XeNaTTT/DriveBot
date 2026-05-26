import 'package:driveassistant_ar/features/location/data/ios_location_runtime.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  const fallback = LocationStatus(
    speedKph: 84,
    headingDegrees: 58,
    gpsFixStatus: GpsFixStatus.unavailable,
    isMock: true,
    isSpeedEstimatedFromGps: false,
  );

  test('null/invalid speed uses fallback speed safely', () {
    final status = IosLocationRuntime.mapPositionToLocationStatus(
      position: _position(speed: -1, heading: 120, accuracy: 10),
      fallback: fallback,
    );

    expect(status.speedKph, 84);
    expect(status.headingDegrees, 120);
    expect(status.isMock, isTrue);
  });

  test('location service unavailable maps to unavailable gps fix', () {
    expect(IosLocationRuntime.fixFromAccuracy(120), GpsFixStatus.unavailable);
  });

  test('real speed and heading become real sensor mode', () {
    final status = IosLocationRuntime.mapPositionToLocationStatus(
      position: _position(speed: 20, heading: 270, accuracy: 8),
      fallback: fallback,
    );

    expect(status.speedKph, 72);
    expect(status.headingDegrees, 270);
    expect(status.isMock, isFalse);
    expect(status.isSpeedEstimatedFromGps, isTrue);
  });
}

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
