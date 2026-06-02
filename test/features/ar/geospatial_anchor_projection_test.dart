import 'package:driveassistant_ar/features/ar/application/ar_anchor_projection_service.dart';
import 'package:driveassistant_ar/features/ar/application/ar_info_object_factory.dart';
import 'package:driveassistant_ar/features/ar/application/geo_ar_coordinate_mapper.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_anchor_candidate_mapper.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_runtime_state.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_world_anchor_state.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = GeoArCoordinateMapper();

  test('lat/lon conversion maps north to positive north meters', () {
    final coordinate = mapper.localCoordinate(
      currentLatitude: 52.0,
      currentLongitude: 13.0,
      targetLatitude: 52.001,
      targetLongitude: 13.0,
    );

    expect(coordinate.northMeters, greaterThan(100));
    expect(coordinate.eastMeters.abs(), lessThan(1));
  });

  test('bearing conversion maps object north of user forward in ARKit', () {
    final coordinate = mapper.localCoordinate(
      currentLatitude: 52.0,
      currentLongitude: 13.0,
      targetLatitude: 52.001,
      targetLongitude: 13.0,
    );
    final arKit = mapper.arKitCoordinateFor(coordinate);

    expect(arKit.z, lessThan(0));
    expect(arKit.x.abs(), lessThan(1));
  });

  test('object east of user maps right in ARKit', () {
    final coordinate = mapper.localCoordinate(
      currentLatitude: 52.0,
      currentLongitude: 13.0,
      targetLatitude: 52.0,
      targetLongitude: 13.001,
    );
    final arKit = mapper.arKitCoordinateFor(coordinate);

    expect(arKit.x, greaterThan(60));
    expect(arKit.z.abs(), lessThan(1));
  });

  test('distance label remains GPS-based', () {
    final object = const ArInfoObjectFactory().create(
      _warning(latitude: 52.001, longitude: 13.0, distance: 9999),
      _liveLocation,
    );
    final candidates = const ArAnchorCandidateMapper().geoCandidatesFromObjects(
      objects: [object],
      location: _liveLocation,
    );

    expect(
      candidates.single.distanceMeters.round(),
      inInclusiveRange(110, 112),
    );
    expect(object.formattedDistance, '110 m');
  });

  test('ARKit unavailable uses projection fallback', () {
    final object = const ArInfoObjectFactory().create(
      _warning(latitude: 52.001, longitude: 13.0),
      _liveLocation,
    );
    final result = const ArAnchorProjectionService().project(
      objects: [object],
      location: _liveLocation,
      runtimeState: const ArRuntimeState.fallback('Kamera-Fallback'),
    );

    expect(result.statusLabel, 'Kamera-Fallback');
    expect(result.markers, hasLength(1));
    expect(result.markers.single.isWorldAnchored, isFalse);
  });

  test(
    'tracking limited shows Tracking eingeschränkt and hides geo marker',
    () {
      final object = const ArInfoObjectFactory().create(
        _warning(latitude: 52.001, longitude: 13.0),
        _liveLocation,
      );
      final result = const ArAnchorProjectionService().project(
        objects: [object],
        location: _liveLocation,
        runtimeState: const ArRuntimeState.available(
          isRunning: true,
        ).copyWith(trackingQuality: ArTrackingQuality.limited),
      );

      expect(result.statusLabel, 'Tracking eingeschränkt');
      expect(result.markers, isEmpty);
    },
  );

  test('marker with no coordinates is not anchored', () {
    final object = const ArInfoObjectFactory().create(
      _warning(),
      _liveLocation,
    );
    final result = const ArAnchorProjectionService().project(
      objects: [object],
      location: _liveLocation,
      runtimeState: const ArRuntimeState.available(isRunning: true),
    );

    expect(result.candidates, isEmpty);
    expect(result.markers.single.isWorldAnchored, isFalse);
  });

  test('native ARKit projection replaces fallback bearing screen position', () {
    final object = const ArInfoObjectFactory().create(
      _warning(latitude: 52.001, longitude: 13.0),
      _liveLocation,
    );
    final result = const ArAnchorProjectionService().project(
      objects: [object],
      location: _liveLocation,
      runtimeState: const ArRuntimeState.available(isRunning: true),
      nativeAnchorStates: {
        object.id: ArWorldAnchorState(
          id: object.id,
          trackingQuality: ArTrackingQuality.stable,
          isAnchored: true,
          normalizedX: 0.25,
          top: 0.31,
          isVisible: true,
          trackingConfidence: 1,
          projectionSource: ArProjectionSource.native,
          lastRecalibrationAgeSeconds: 1.2,
        ),
      },
    );

    expect(result.projectionSourceLabel, 'native');
    expect(result.lastRecalibrationAgeSeconds, 1.2);
    expect(result.markers.single.normalizedX, 0.25);
    expect(result.markers.single.top, 0.31);
    expect(result.markers.single.isWorldAnchored, isTrue);
  });

  test('native ARKit projection can surface marker outside fallback FOV', () {
    final object = const ArInfoObjectFactory().create(
      _warning(latitude: 52.001, longitude: 13.0),
      _liveLocation.copyWith(headingDegrees: 90),
    );
    final result = const ArAnchorProjectionService().project(
      objects: [object],
      location: _liveLocation.copyWith(headingDegrees: 90),
      runtimeState: const ArRuntimeState.available(isRunning: true),
      nativeAnchorStates: {
        object.id: ArWorldAnchorState(
          id: object.id,
          trackingQuality: ArTrackingQuality.stable,
          isAnchored: true,
          normalizedX: 0.52,
          top: 0.28,
          isVisible: true,
          trackingConfidence: 1,
          projectionSource: ArProjectionSource.native,
        ),
      },
    );

    expect(result.markers, hasLength(1));
    expect(result.markers.single.normalizedX, 0.52);
    expect(result.hiddenByFov, 1);
  });

  test('native tracking and FOV hidden counts are reported separately', () {
    final visible = const ArInfoObjectFactory().create(
      _warning(id: 'visible', latitude: 52.001, longitude: 13.0),
      _liveLocation,
    );
    final trackingHidden = const ArInfoObjectFactory().create(
      _warning(id: 'tracking', latitude: 52.002, longitude: 13.0),
      _liveLocation,
    );
    final fovHidden = const ArInfoObjectFactory().create(
      _warning(id: 'fov', latitude: 52.003, longitude: 13.0),
      _liveLocation,
    );
    final result = const ArAnchorProjectionService().project(
      objects: [visible, trackingHidden, fovHidden],
      location: _liveLocation,
      runtimeState: const ArRuntimeState.available(isRunning: true),
      nativeAnchorStates: {
        'visible': ArWorldAnchorState(
          id: 'visible',
          trackingQuality: ArTrackingQuality.stable,
          isAnchored: true,
          normalizedX: 0.5,
          top: 0.3,
          isVisible: true,
          trackingConfidence: 1,
          projectionSource: ArProjectionSource.native,
        ),
        'tracking': ArWorldAnchorState(
          id: 'tracking',
          trackingQuality: ArTrackingQuality.limited,
          isAnchored: true,
          isVisible: false,
          hiddenReason: 'tracking',
          trackingConfidence: 0.3,
          projectionSource: ArProjectionSource.native,
        ),
        'fov': ArWorldAnchorState(
          id: 'fov',
          trackingQuality: ArTrackingQuality.stable,
          isAnchored: true,
          isVisible: false,
          hiddenReason: 'fov',
          trackingConfidence: 1,
          projectionSource: ArProjectionSource.native,
        ),
      },
    );

    expect(result.markers, hasLength(1));
    expect(result.hiddenByTracking, 1);
    expect(result.hiddenByFov, 1);
  });
}

const _liveLocation = LocationStatus(
  speedKph: 0,
  headingDegrees: 0,
  gpsFixStatus: GpsFixStatus.strong,
  isMock: false,
  isSpeedEstimatedFromGps: false,
  isHeadingFromCompass: true,
  latitude: 52,
  longitude: 13,
  accuracyMeters: 8,
);

HudWarningItem _warning({
  double? latitude,
  double? longitude,
  int distance = 111,
  String? id,
}) => HudWarningItem(
  id: id,
  type: WarningType.speedCamera,
  title: 'Blitzer',
  detail: 'GPS-Test',
  distanceMeters: distance,
  bearingDegrees: 0,
  severity: 4,
  latitude: latitude,
  longitude: longitude,
);
