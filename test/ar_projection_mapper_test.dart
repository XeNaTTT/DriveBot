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

  test('marker y position is stable without altitude', () {
    final markers = mapper.project(
      objects: [_object(_warning(0, distanceMeters: 1600))],
      userHeadingDegrees: 0,
    );
    expect(markers.single.top, closeTo(0.38, 0.02));
  });

  test('pitch changes produce smoothed y changes through previous markers', () {
    final object = _object(_warning(0, distanceMeters: 700));
    final first = mapper
        .project(
          objects: [object],
          userHeadingDegrees: 0,
          devicePitchDegrees: 0,
        )
        .single;
    final pitched = mapper
        .project(
          objects: [object],
          userHeadingDegrees: 0,
          devicePitchDegrees: 18,
        )
        .single;
    expect((pitched.top - first.top).abs(), lessThan(0.08));
  });

  test('distant markers stay near horizon', () {
    final marker = mapper
        .project(
          objects: [_object(_warning(0, distanceMeters: 2500))],
          userHeadingDegrees: 0,
        )
        .single;
    expect(marker.top, closeTo(0.38, 0.03));
  });

  test('nearby markers can render lower than distant markers', () {
    final near = mapper
        .project(
          objects: [_object(_warning(0, distanceMeters: 120))],
          userHeadingDegrees: 0,
        )
        .single;
    final far = mapper
        .project(
          objects: [_object(_warning(0, distanceMeters: 2500))],
          userHeadingDegrees: 0,
        )
        .single;
    expect(near.top, greaterThan(far.top));
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

HudWarningItem _warning(int bearing, {int distanceMeters = 1200}) =>
    HudWarningItem(
      type: WarningType.speedCamera,
      title: 'A3 Suben',
      detail: 'Abstand halten',
      distanceMeters: distanceMeters,
      bearingDegrees: bearing,
      severity: 3,
    );
