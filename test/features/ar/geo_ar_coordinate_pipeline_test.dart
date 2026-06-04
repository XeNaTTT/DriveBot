import 'package:driveassistant_ar/features/ar/application/ar_anchor_projection_service.dart';
import 'package:driveassistant_ar/features/ar/application/ar_geo_recalibration_policy.dart';
import 'package:driveassistant_ar/features/ar/application/ar_info_object_factory.dart';
import 'package:driveassistant_ar/features/ar/application/geo_ar_coordinate_mapper.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_marker_model.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_projection_smoothing.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_runtime_state.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const coordinateMapper = GeoArCoordinateMapper();

  test('lat/lon to ENU conversion maps an east target to positive east', () {
    final coordinate = coordinateMapper.localCoordinate(
      currentLatitude: 52,
      currentLongitude: 13,
      targetLatitude: 52,
      targetLongitude: 13.001,
    );

    expect(coordinate.eastMeters, greaterThan(60));
    expect(coordinate.northMeters.abs(), lessThan(1));
  });

  test('lat/lon to ENU conversion maps a north target forward', () {
    final coordinate = coordinateMapper.localCoordinate(
      currentLatitude: 52,
      currentLongitude: 13,
      targetLatitude: 52.001,
      targetLongitude: 13,
    );
    final arKit = coordinateMapper.arKitCoordinateFor(coordinate);

    expect(coordinate.northMeters, greaterThan(100));
    expect(arKit.z, lessThan(0));
  });

  test(
    'missing altitude keeps ARKit y stable instead of scattering markers',
    () {
      final coordinate = coordinateMapper.localCoordinate(
        currentLatitude: 52,
        currentLongitude: 13,
        targetLatitude: 52.01,
        targetLongitude: 13.01,
        currentAltitude: 85,
      );

      expect(coordinate.upMeters, 0);
      expect(coordinateMapper.arKitCoordinateFor(coordinate).y, 0);
    },
  );

  test('stable marker ids survive distance changes for the same report id', () {
    final first = const ArInfoObjectFactory().create(
      _warning(id: 'community-speed-camera-42', distanceMeters: 120),
      _location,
    );
    final second = const ArInfoObjectFactory().create(
      _warning(id: 'community-speed-camera-42', distanceMeters: 160),
      _location,
    );

    expect(first.id, second.id);
  });

  test('recalibration threshold ignores tiny movement and reacts to drift', () {
    const policy = ArGeoRecalibrationPolicy();
    const origin = ArGeoSessionOrigin(
      latitude: 52,
      longitude: 13,
      headingDegrees: 10,
      trackingQualityLabel: 'stable',
    );

    expect(
      policy.shouldRecalibrate(
        origin: origin,
        latitude: 52.00001,
        longitude: 13,
        headingDegrees: 12,
        trackingQualityLabel: 'stable',
      ),
      isFalse,
    );
    expect(
      policy.shouldRecalibrate(
        origin: origin,
        latitude: 52.00001,
        longitude: 13,
        headingDegrees: 19,
        trackingQualityLabel: 'stable',
      ),
      isTrue,
    );
    expect(
      policy.shouldRecalibrate(
        origin: origin,
        latitude: 52.00008,
        longitude: 13,
        headingDegrees: 12,
        trackingQualityLabel: 'stable',
      ),
      isTrue,
    );
  });

  test('fallback projection works when ARKit is unavailable', () {
    final object = const ArInfoObjectFactory().create(
      _warning(latitude: 52.001, longitude: 13),
      _location,
    );

    final result = const ArAnchorProjectionService().project(
      objects: [object],
      location: _location,
      runtimeState: const ArRuntimeState.fallback('Kamera-Fallback'),
    );

    expect(result.projectionSourceLabel, 'fallback');
    expect(result.markers.single.isWorldAnchored, isFalse);
  });

  test('marker smoothing reduces jumps between projected positions', () {
    final object = const ArInfoObjectFactory().create(_warning(), _location);
    final previous = ArMarkerModel(
      infoObject: object,
      relativeBearing: 0,
      normalizedX: 0.2,
      top: 0.4,
    );
    final current = ArMarkerModel(
      infoObject: object,
      relativeBearing: 0,
      normalizedX: 0.8,
      top: 0.7,
    );

    final smoothedX = ArProjectionSmoothing.smoothLinear(
      previous: previous.normalizedX,
      current: current.normalizedX,
      factor: 0.35,
    );
    final smoothedY = ArProjectionSmoothing.smoothLinear(
      previous: previous.top,
      current: current.top,
      factor: 0.35,
    );

    expect(smoothedX, lessThan(current.normalizedX));
    expect(smoothedX, greaterThan(previous.normalizedX));
    expect(smoothedY, lessThan(current.top));
  });

  test('expired community warnings are not projected', () {
    final expired = const ArInfoObjectFactory().create(
      _warning(
        id: 'expired-community-warning',
        latitude: 52.001,
        longitude: 13,
        validTo: _past,
      ),
      _location,
    );

    final result = const ArAnchorProjectionService().project(
      objects: [expired],
      location: _location,
      runtimeState: const ArRuntimeState.available(isRunning: true),
    );

    expect(result.candidates, isEmpty);
    expect(result.projections, isEmpty);
    expect(result.markers, isEmpty);
  });
}

final _past = DateTime.utc(2020);

const _location = LocationStatus(
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
  String? id,
  double? latitude,
  double? longitude,
  int distanceMeters = 120,
  DateTime? validTo,
}) => HudWarningItem(
  id: id,
  type: WarningType.speedCamera,
  title: 'Blitzer',
  detail: 'Community-Test',
  distanceMeters: distanceMeters,
  bearingDegrees: 0,
  severity: 4,
  source: 'Community',
  latitude: latitude,
  longitude: longitude,
  validTo: validTo,
);
