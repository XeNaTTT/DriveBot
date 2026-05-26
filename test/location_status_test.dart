import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps heading to cardinal direction', () {
    const status = LocationStatus(
      speedKph: 100,
      headingDegrees: 90,
      gpsFixStatus: GpsFixStatus.strong,
      isMock: false,
      isSpeedEstimatedFromGps: true,
    );

    expect(status.cardinalHeading, 'E');
  });

  test('maps heading boundary to north-east', () {
    const status = LocationStatus(
      speedKph: 0,
      headingDegrees: 44,
      gpsFixStatus: GpsFixStatus.moderate,
      isMock: false,
      isSpeedEstimatedFromGps: true,
    );

    expect(status.cardinalHeading, 'NE');
  });

  test('supports unavailable gps status for service-disabled fallback', () {
    const status = LocationStatus(
      speedKph: 84,
      headingDegrees: 58,
      gpsFixStatus: GpsFixStatus.unavailable,
      isMock: true,
      isSpeedEstimatedFromGps: false,
    );

    expect(status.gpsFixStatus, GpsFixStatus.unavailable);
    expect(status.isMock, isTrue);
  });
}
