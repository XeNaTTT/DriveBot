import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:driveassistant_ar/features/location/domain/sensor_permission_status.dart';
import 'package:driveassistant_ar/features/sensors/domain/heading_utils.dart';
import 'package:driveassistant_ar/features/sensors/domain/sensor_runtime_state.dart';
import 'package:driveassistant_ar/features/sensors/domain/speed_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GPS speed conversion', () {
    test('converts m/s to km/h', () {
      expect(SpeedUtils.speedKphFromMetersPerSecond(20), 72);
    });

    test('null speed is stationary/unknown', () {
      expect(SpeedUtils.speedKphFromMetersPerSecond(null), 0);
    });

    test('negative speed is stationary/unknown', () {
      expect(SpeedUtils.speedKphFromMetersPerSecond(-1), 0);
    });

    test('unrealistic speed is clamped', () {
      expect(SpeedUtils.speedKphFromMetersPerSecond(120), 260);
    });

    test('fallback speed is preserved when runtime location is unavailable',
        () {
      expect(
        SpeedUtils.fallbackAwareSpeedKph(
          metersPerSecond: null,
          fallbackSpeedKph: 84,
        ),
        84,
      );
    });
  });

  group('heading normalization', () {
    test('normalizes negative and oversized headings', () {
      expect(HeadingUtils.normalizeHeading(-10), 350);
      expect(HeadingUtils.normalizeHeading(725), 5);
    });

    test('maps cardinal directions', () {
      expect(HeadingUtils.cardinalDirection(0), 'N');
      expect(HeadingUtils.cardinalDirection(44), 'NE');
      expect(HeadingUtils.cardinalDirection(90), 'E');
      expect(HeadingUtils.cardinalDirection(225), 'SW');
      expect(HeadingUtils.cardinalDirection(315), 'NW');
    });

    test('falls back from unavailable compass to gps course then mock heading',
        () {
      expect(
        HeadingUtils.fallbackAwareHeading(
          compassHeading: null,
          gpsCourse: 181,
          fallbackHeading: 58,
        ),
        181,
      );
      expect(
        HeadingUtils.fallbackAwareHeading(
          compassHeading: double.nan,
          gpsCourse: double.infinity,
          fallbackHeading: 58,
        ),
        58,
      );
    });

    test('invalid heading values return null', () {
      expect(HeadingUtils.normalizeHeading(double.nan), isNull);
      expect(HeadingUtils.normalizeHeading(double.infinity), isNull);
    });
  });

  group('unified sensor runtime mode', () {
    test('Live AR requires camera, location, and heading', () {
      final state = SensorRuntimeState(
        cameraAvailable: true,
        locationStatus: _location(
          gpsFixStatus: GpsFixStatus.strong,
          isHeadingFromCompass: true,
        ),
        permissionStatus: _permissions,
        motionStatus: const MotionRuntimeState(
          availability: MotionRuntimeAvailability.available,
        ),
      );

      expect(state.mode, SensorRuntimeMode.liveAr);
      expect(state.modeLabel, 'Live AR');
    });

    test('Partial live is used for degraded sensors', () {
      final state = SensorRuntimeState(
        cameraAvailable: true,
        locationStatus: _location(gpsFixStatus: GpsFixStatus.denied),
        permissionStatus: _permissions,
        motionStatus: const MotionRuntimeState.unavailable(),
      );

      expect(state.mode, SensorRuntimeMode.partialLive);
      expect(state.compactMessages, contains('Location needed'));
      expect(state.compactMessages, contains('Compass unavailable'));
    });

    test('Fallback is used when mostly mock data is active', () {
      final state = SensorRuntimeState(
        cameraAvailable: false,
        locationStatus: _location(gpsFixStatus: GpsFixStatus.unavailable),
        permissionStatus: _permissions,
        motionStatus: const MotionRuntimeState.unavailable(),
      );

      expect(state.mode, SensorRuntimeMode.fallback);
      expect(state.compactMessages, contains('Fallback mode'));
    });

    test('motion unavailable fallback is stable', () {
      const motion = MotionRuntimeState.unavailable();
      expect(motion.isAvailable, isFalse);
      expect(motion.pitchDegrees, isNull);
      expect(motion.rollDegrees, isNull);
    });
  });
}

const _permissions = SensorPermissionStatus(
  camera: SensorPermissionState.granted,
  location: SensorPermissionState.granted,
  motion: SensorPermissionState.unavailable,
);

LocationStatus _location({
  required GpsFixStatus gpsFixStatus,
  bool isHeadingFromCompass = false,
}) {
  return LocationStatus(
    speedKph: 84,
    headingDegrees: 58,
    gpsFixStatus: gpsFixStatus,
    isMock: gpsFixStatus == GpsFixStatus.unavailable,
    isSpeedEstimatedFromGps: gpsFixStatus != GpsFixStatus.unavailable,
    isHeadingFromCompass: isHeadingFromCompass,
  );
}
