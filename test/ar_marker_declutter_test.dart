import 'package:driveassistant_ar/features/ar/application/ar_info_object_factory.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_marker_declutter.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_marker_model.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const declutter = ArMarkerDeclutter(maxVisibleMarkers: 3);

  test('overlapping markers are decluttered', () {
    final result = declutter.apply(markers: _markers(_warnings));

    expect(result.visibleMarkers.length, 3);
    expect(result.hiddenByOverlap, greaterThan(0));
    expect(
      result.visibleMarkers.map((marker) => marker.top).toSet().length,
      greaterThan(1),
    );
  });

  test('priority keeps mobile and fixed speed cameras visible', () {
    final result = declutter.apply(markers: _markers(_warnings));

    expect(
      result.visibleMarkers.where(
        (marker) => marker.infoObject.type == WarningType.speedCamera,
      ),
      hasLength(2),
    );
  });

  test('+X weitere appears when markers are collapsed', () {
    final result = declutter.apply(markers: _markers(_warnings));

    expect(result.hiddenByOverlap, 2);
  });
}

List<ArMarkerModel> _markers(List<HudWarningItem> warnings) {
  final objects = const ArInfoObjectFactory().createAll(
    warnings: warnings,
    location: _location,
  );
  return objects
      .map(
        (object) => ArMarkerModel(
          infoObject: object,
          relativeBearing: 0,
          normalizedX: 0.5,
          top: 0.38,
        ),
      )
      .toList(growable: false);
}

const _location = LocationStatus(
  speedKph: 0,
  headingDegrees: 0,
  gpsFixStatus: GpsFixStatus.unavailable,
  isMock: true,
  isSpeedEstimatedFromGps: false,
);

const _warnings = [
  HudWarningItem(
    type: WarningType.notice,
    title: 'Berlin Hinweis',
    detail: 'Verkehr',
    distanceMeters: 300,
    bearingDegrees: 0,
    severity: 1,
  ),
  HudWarningItem(
    type: WarningType.speedCamera,
    title: 'Mobiler Blitzer',
    detail: 'Community',
    distanceMeters: 250,
    bearingDegrees: 0,
    severity: 4,
  ),
  HudWarningItem(
    type: WarningType.roadwork,
    title: 'Baustelle',
    detail: 'Berlin',
    distanceMeters: 150,
    bearingDegrees: 0,
    severity: 2,
  ),
  HudWarningItem(
    type: WarningType.speedCamera,
    title: 'Fester Blitzer',
    detail: 'Stationär',
    distanceMeters: 700,
    bearingDegrees: 0,
    severity: 3,
  ),
  HudWarningItem(
    type: WarningType.speedLimit,
    title: 'Tempolimit',
    detail: '80',
    distanceMeters: 100,
    bearingDegrees: 0,
    severity: 5,
  ),
];
