import 'package:driveassistant_ar/features/ar/application/ar_anchor_projection_service.dart';
import 'package:driveassistant_ar/features/ar/application/ar_info_object_factory.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_projection_smoothing.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_runtime_state.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:driveassistant_ar/features/warnings/data/api_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/composite_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/mock_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/warning_mapper.dart';
import 'package:driveassistant_ar/features/warnings/domain/warning_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('heading smoothing handles 359 -> 1 degrees correctly', () {
    final smoothed = ArProjectionSmoothing.smoothCircularDegrees(
      previous: 359,
      current: 1,
      factor: 0.5,
    );
    expect(smoothed, closeTo(0, 0.01));
  });

  test('tiny heading changes do not move marker', () {
    final smoothed = ArProjectionSmoothing.smoothCircularDegrees(
      previous: 42,
      current: 42.2,
      factor: 0.5,
      minChangeDegrees: 0.7,
    );
    expect(smoothed, 42);
  });

  test('tiny pitch changes do not move marker', () {
    final smoothed = ArProjectionSmoothing.smoothLinear(
      previous: 4,
      current: 4.1,
      factor: 0.5,
      minChange: 0.35,
    );
    expect(smoothed, 4);
  });

  test('marker id remains stable across distance updates', () {
    final first = _warning(distance: 100).stableId;
    final second = _warning(distance: 140).stableId;
    expect(second, first);
  });

  test('marker ordering is deterministic', () {
    final objects = const ArInfoObjectFactory().createAll(
      warnings: [
        HudWarningItem(
          type: WarningType.speedCamera,
          title: 'B',
          detail: 'Test',
          distanceMeters: 100,
          bearingDegrees: 0,
          severity: 3,
          source: 'z',
        ),
        HudWarningItem(
          type: WarningType.speedCamera,
          title: 'A',
          detail: 'Test',
          distanceMeters: 100,
          bearingDegrees: 0,
          severity: 3,
          source: 'a',
        ),
      ],
      location: _location,
    );
    final result = const ArAnchorProjectionService().project(
      objects: objects,
      location: _location,
      runtimeState: ArRuntimeState.fallback('Kamera-Fallback'),
    );
    expect(result.markers.map((m) => m.infoObject.sourceLabel), ['a', 'z']);
  });

  test('selected marker stays selected after projection update', () {
    final object = const ArInfoObjectFactory().create(
      _warning(id: 'stable'),
      _location,
    );
    final first = const ArAnchorProjectionService().project(
      objects: [object],
      location: _location,
      runtimeState: ArRuntimeState.fallback('Kamera-Fallback'),
      selectedInfoObjectId: 'stable',
    );
    final second = const ArAnchorProjectionService().project(
      objects: [object],
      location: _location.copyWith(headingDegrees: 1),
      runtimeState: ArRuntimeState.fallback('Kamera-Fallback'),
      previousMarkers: {
        for (final marker in first.markers) marker.infoObject.id: marker,
      },
      selectedInfoObjectId: 'stable',
    );
    expect(second.markers.single.infoObject.id, 'stable');
  });

  test('data refresh does not recreate marker ids unnecessarily', () async {
    var calls = 0;
    final repository = CompositeWarningRepository(
      primary: ApiWarningRepository(
        client: (_) async {
          calls++;
          return [
            ApiWarningPayload(
              type: 'speed_camera',
              title: 'Blitzer',
              detail: 'A1',
              distanceMeters: calls == 1 ? 100 : 130,
              bearingDegrees: 0,
              severity: 3,
            ),
          ];
        },
      ),
      fallback: MockWarningRepository(warnings: const []),
    );
    await repository.getWarnings(const WarningRequest.fallback());
    final first = repository.getNearbyWarnings().single.stableId;
    await repository.getWarnings(const WarningRequest.fallback());
    final second = repository.getNearbyWarnings().single.stableId;
    expect(second, first);
  });
}

const _location = LocationStatus(
  speedKph: 0,
  headingDegrees: 0,
  gpsFixStatus: GpsFixStatus.unavailable,
  isMock: true,
  isSpeedEstimatedFromGps: false,
);

HudWarningItem _warning({int distance = 100, String? id}) => HudWarningItem(
  id: id,
  type: WarningType.speedCamera,
  title: 'Blitzer',
  detail: 'A1',
  distanceMeters: distance,
  bearingDegrees: 0,
  severity: 3,
);
