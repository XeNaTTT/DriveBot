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

  test(
    'two overlapping markers do not alternate visibility on tiny movement',
    () {
      const oneVisible = ArMarkerDeclutter(maxVisibleMarkers: 1);
      final now = DateTime.utc(2026, 6, 4, 12);
      final first = oneVisible.apply(
        markers: _markers(_overlappingPair),
        now: now,
      );
      final firstVisibleId = first.visibleMarkers.single.infoObject.id;

      final moved = oneVisible.apply(
        markers: _markers(_overlappingPair.reversed.toList(), x: 0.501),
        previousState: first.state,
        now: now.add(const Duration(milliseconds: 500)),
      );

      expect(moved.visibleMarkers.single.infoObject.id, firstVisibleId);
    },
  );

  test('visible marker stays visible for hysteresis duration', () {
    const oneVisible = ArMarkerDeclutter(maxVisibleMarkers: 1);
    final now = DateTime.utc(2026, 6, 4, 12);
    final first = oneVisible.apply(
      markers: _markers(_overlappingPair),
      now: now,
    );
    final visibleId = first.visibleMarkers.single.infoObject.id;
    final forced = oneVisible.apply(
      markers: _markers(_preferredSecondPair),
      previousState: first.state,
      now: now.add(const Duration(milliseconds: 1200)),
    );

    expect(
      forced.visibleMarkers.map((m) => m.infoObject.id),
      contains(visibleId),
    );
  });

  test('hidden marker stays hidden for hysteresis duration', () {
    const oneVisible = ArMarkerDeclutter(maxVisibleMarkers: 1);
    final now = DateTime.utc(2026, 6, 4, 12);
    final first = oneVisible.apply(
      markers: _markers(_overlappingPair),
      now: now,
    );
    final hiddenId = first.state.hiddenIds.single;
    final second = oneVisible.apply(
      markers: _markers(_preferredSecondPair),
      previousState: first.state,
      now: now.add(const Duration(milliseconds: 500)),
    );

    expect(
      second.visibleMarkers.map((m) => m.infoObject.id),
      isNot(contains(hiddenId)),
    );
  });

  test('selected marker remains visible during overlap', () {
    const oneVisible = ArMarkerDeclutter(maxVisibleMarkers: 1);
    final markers = _markers(_overlappingPair);
    final selectedId = markers.last.infoObject.id;
    final result = oneVisible.apply(
      markers: markers,
      selectedInfoObjectId: selectedId,
    );

    expect(
      result.visibleMarkers.map((m) => m.infoObject.id),
      contains(selectedId),
    );
  });

  test('deterministic sorting returns stable order', () {
    const declutter = ArMarkerDeclutter(maxVisibleMarkers: 4);
    final shuffled = _markers([
      _sortWarning(
        'later',
        severity: 3,
        source: 'zz',
        distance: 20,
        validFrom: DateTime.utc(2026, 6, 4, 11),
      ),
      _sortWarning('selected', severity: 1, source: 'zz', distance: 5),
      _sortWarning(
        'community',
        severity: 3,
        source: 'Community',
        distance: 100,
      ),
      _sortWarning(
        'berlin',
        severity: 3,
        source: 'Berlin Verkehr',
        distance: 10,
      ),
    ], x: 0.1);
    final selectedId = shuffled[1].infoObject.id;
    final sorted = [...shuffled]
      ..sort((a, b) => declutter.compareDeterministic(a, b, selectedId));

    expect(sorted.map((m) => m.infoObject.title), [
      'selected',
      'community',
      'berlin',
      'later',
    ]);
  });

  test('+X weitere remains stable across tiny projection changes', () {
    const oneVisible = ArMarkerDeclutter(maxVisibleMarkers: 1);
    final now = DateTime.utc(2026, 6, 4, 12);
    final first = oneVisible.apply(markers: _markers(_warnings), now: now);
    final second = oneVisible.apply(
      markers: _markers(_warnings, x: 0.501),
      previousState: first.state,
      now: now.add(const Duration(milliseconds: 200)),
    );

    expect(second.hiddenByOverlap, first.hiddenByOverlap);
  });
}

List<ArMarkerModel> _markers(List<HudWarningItem> warnings, {double x = 0.5}) {
  final objects = const ArInfoObjectFactory().createAll(
    warnings: warnings,
    location: _location,
  );
  return objects
      .map(
        (object) => ArMarkerModel(
          infoObject: object,
          relativeBearing: 0,
          normalizedX: x,
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

const _overlappingPair = [
  HudWarningItem(
    id: 'stable-a',
    type: WarningType.notice,
    title: 'A',
    detail: 'A',
    distanceMeters: 100,
    bearingDegrees: 0,
    severity: 2,
  ),
  HudWarningItem(
    id: 'stable-b',
    type: WarningType.notice,
    title: 'B',
    detail: 'B',
    distanceMeters: 110,
    bearingDegrees: 0,
    severity: 1,
  ),
];

const _preferredSecondPair = [
  HudWarningItem(
    id: 'stable-a',
    type: WarningType.notice,
    title: 'A',
    detail: 'A',
    distanceMeters: 100,
    bearingDegrees: 0,
    severity: 1,
  ),
  HudWarningItem(
    id: 'stable-b',
    type: WarningType.notice,
    title: 'B',
    detail: 'B',
    distanceMeters: 110,
    bearingDegrees: 0,
    severity: 5,
  ),
];

HudWarningItem _sortWarning(
  String title, {
  required int severity,
  required String source,
  required int distance,
  DateTime? validFrom,
}) => HudWarningItem(
  id: 'sort-$title',
  type: WarningType.notice,
  title: title,
  detail: title,
  distanceMeters: distance,
  bearingDegrees: 0,
  severity: severity,
  source: source,
  validFrom: validFrom,
);
