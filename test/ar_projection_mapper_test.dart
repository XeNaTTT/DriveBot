import 'package:driveassistant_ar/features/ar/application/ar_info_object_factory.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_info_object.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_projection_mapper.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = ArProjectionMapper(horizontalFovDegrees: 60);

  test('object outside FOV is hidden', () {
    final markers = mapper.project(
      objects: [_object(_warning(95))],
      userHeadingDegrees: 0,
    );
    expect(markers, isEmpty);
  });

  test('object inside FOV is visible', () {
    final markers = mapper.project(
      objects: [_object(_warning(20))],
      userHeadingDegrees: 0,
    );
    expect(markers, hasLength(1));
  });

  test('maps left center right x positions', () {
    final markers = mapper.project(
      objects: [
        _object(_warning(330)),
        _object(_warning(0)),
        _object(_warning(30)),
      ],
      userHeadingDegrees: 0,
    );
    expect(markers[0].normalizedX, closeTo(0, 0.01));
    expect(markers[1].normalizedX, closeTo(0.5, 0.01));
    expect(markers[2].normalizedX, closeTo(1, 0.01));
  });
}

ArInfoObject _object(HudWarningItem warning) =>
    const ArInfoObjectFactory().create(warning, _location);

const _location = LocationStatus(
  speedKph: 0,
  headingDegrees: 0,
  gpsFixStatus: GpsFixStatus.unavailable,
  isMock: true,
  isSpeedEstimatedFromGps: false,
);

HudWarningItem _warning(int bearing) => HudWarningItem(
  type: WarningType.speedCamera,
  title: 'A3 Suben',
  detail: 'Abstand halten',
  distanceMeters: 1200,
  bearingDegrees: bearing,
  severity: 3,
);
