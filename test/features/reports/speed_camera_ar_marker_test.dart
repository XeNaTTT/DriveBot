import 'package:driveassistant_ar/features/ar/application/ar_info_object_factory.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_info_object.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_projection_mapper.dart';
import 'package:driveassistant_ar/features/ar/presentation/ar_marker_layer.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:driveassistant_ar/features/reports/presentation/speed_camera_ar_marker.dart';
import 'package:driveassistant_ar/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Speed camera silhouette renders', (tester) async {
    await tester.pumpWidget(_markerApp(_object(_warning('Mobiler Blitzer'))));
    expect(find.byKey(const Key('speed-camera-ar-marker')), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('Mobile/fixed labels render in German', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Column(
          children: [
            SpeedCameraArMarker(
              infoObject: _object(_warning('Mobiler Blitzer')),
            ),
            SpeedCameraArMarker(
              infoObject: _object(_warning('Fester Blitzer')),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Mobiler Blitzer'), findsOneWidget);
    expect(find.text('Fester Blitzer'), findsOneWidget);
  });

  test('Marker inside FOV is visible', () {
    final markers = const ArProjectionMapper().project(
      objects: [_object(_warning('Mobiler Blitzer', bearing: 58))],
      userHeadingDegrees: 58,
    );
    expect(markers, hasLength(1));
  });

  test('Marker outside FOV is hidden', () {
    final markers = const ArProjectionMapper().project(
      objects: [_object(_warning('Mobiler Blitzer', bearing: 140))],
      userHeadingDegrees: 58,
    );
    expect(markers, isEmpty);
  });

  test('Expired marker is hidden before projection', () {
    final now = DateTime.utc(2026, 5, 29);
    final warnings =
        [
          _warning(
            'Mobiler Blitzer',
            validTo: now.subtract(const Duration(minutes: 1)),
          ),
        ].where(
          (warning) => warning.validTo == null || warning.validTo!.isAfter(now),
        );
    expect(warnings, isEmpty);
  });

  testWidgets('Label is clamped inside screen', (tester) async {
    final markers = const ArProjectionMapper().project(
      objects: [_object(_warning('Mobiler Blitzer', bearing: 30))],
      userHeadingDegrees: 58,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SizedBox(
          width: 320,
          height: 568,
          child: ArMarkerLayer(markers: markers),
        ),
      ),
    );
    final rect = tester.getRect(
      find.byKey(const Key('speed-camera-ar-marker')),
    );
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
  });
}

Widget _markerApp(ArInfoObject object) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(
    body: Center(child: SpeedCameraArMarker(infoObject: object)),
  ),
);

ArInfoObject _object(HudWarningItem warning) =>
    const ArInfoObjectFactory().create(warning, _location);

const _location = LocationStatus(
  speedKph: 0,
  headingDegrees: 58,
  gpsFixStatus: GpsFixStatus.unavailable,
  isMock: true,
  isSpeedEstimatedFromGps: false,
);

HudWarningItem _warning(String title, {int bearing = 58, DateTime? validTo}) =>
    HudWarningItem(
      type: WarningType.speedCamera,
      title: title,
      detail: 'Quelle: Community',
      distanceMeters: 350,
      bearingDegrees: bearing,
      severity: 5,
      validTo: validTo,
    );
