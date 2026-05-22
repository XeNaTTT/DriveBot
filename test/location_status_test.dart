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
}
