import 'package:driveassistant_ar/features/ar/application/ar_info_object_factory.dart';
import 'package:driveassistant_ar/features/ar/application/distance_formatter.dart';
import 'package:driveassistant_ar/features/data_sources/domain/data_source_registry.dart';
import 'package:driveassistant_ar/features/data_sources/domain/data_source_status.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_repository.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/hud/presentation/hud_screen.dart';
import 'package:driveassistant_ar/features/location/domain/location_repository.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:driveassistant_ar/features/location/domain/permission_repository.dart';
import 'package:driveassistant_ar/features/location/domain/sensor_permission_status.dart';
import 'package:driveassistant_ar/shared/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('live distance', () {
    const formatter = DistanceFormatter();

    test('distance decreases when user moves closer', () {
      final far = _factory.create(_coordinateWarning, _location(longitude: 0));
      final near = _factory.create(
        _coordinateWarning,
        _location(longitude: 0.002),
      );
      expect(near.distanceMeters!, lessThan(far.distanceMeters!));
    });

    test('distance increases when user moves away', () {
      final near = _factory.create(
        _coordinateWarning,
        _location(longitude: 0.002),
      );
      final far = _factory.create(_coordinateWarning, _location(longitude: 0));
      expect(far.distanceMeters!, greaterThan(near.distanceMeters!));
    });

    test('distance formatting under 100 m', () {
      expect(formatter.format(distanceMeters: 87), '85 m');
    });

    test('distance formatting between 100 m and 1 km', () {
      expect(formatter.format(distanceMeters: 448), '450 m');
      expect(formatter.format(distanceMeters: 763), '775 m');
    });

    test('distance formatting over 1 km', () {
      expect(formatter.format(distanceMeters: 1234), '1,2 km');
    });

    test('poor GPS accuracy uses ca.', () {
      expect(
        formatter.format(distanceMeters: 448, accuracyMeters: 80),
        'ca. 450 m',
      );
    });

    test('missing location shows Entfernung unbekannt', () {
      final object = _factory.create(
        _coordinateWarning,
        const LocationStatus(
          speedKph: 0,
          headingDegrees: 0,
          gpsFixStatus: GpsFixStatus.unavailable,
          isMock: true,
          isSpeedEstimatedFromGps: false,
        ),
      );
      expect(object.formattedDistance, 'Entfernung unbekannt');
    });
  });

  group('expandable AR info objects', () {
    testWidgets('AR marker label updates when location changes', (
      tester,
    ) async {
      final location = ValueNotifier(_location(longitude: 0));
      await tester.pumpWidget(_hud(location));
      expect(find.textContaining('450 m'), findsWidgets);

      location.value = _location(longitude: 0.002);
      await tester.pump();
      expect(find.textContaining('230 m'), findsWidgets);
    });

    testWidgets('tapping marker expands detail card', (tester) async {
      await tester.pumpWidget(_hud(ValueNotifier(_location(longitude: 0))));
      await tester.tap(find.byKey(const Key('ar-marker-speedCamera')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ar-info-detail-card')), findsOneWidget);
      expect(find.text('Entfernung'), findsOneWidget);
    });

    testWidgets('tapping another marker switches detail card', (tester) async {
      await tester.pumpWidget(
        _hud(ValueNotifier(_location(longitude: 0)), warnings: _twoWarnings),
      );
      await tester.tap(find.byKey(const Key('ar-marker-speedCamera')));
      await tester.pumpAndSettle();
      expect(find.text('Community Blitzer'), findsWidgets);

      await tester.tap(find.byKey(const Key('ar-marker-chargingStation')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ar-info-detail-card')), findsOneWidget);
      expect(find.text('Schnelllader'), findsWidgets);
    });

    testWidgets('tapping close collapses detail card', (tester) async {
      await tester.pumpWidget(_hud(ValueNotifier(_location(longitude: 0))));
      await tester.tap(find.byKey(const Key('ar-marker-speedCamera')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ar-info-detail-card')), findsNothing);
    });

    testWidgets('only one detail card is visible at a time', (tester) async {
      await tester.pumpWidget(
        _hud(ValueNotifier(_location(longitude: 0)), warnings: _twoWarnings),
      );
      await tester.tap(find.byKey(const Key('ar-marker-speedCamera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ar-marker-chargingStation')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ar-info-detail-card')), findsOneWidget);
    });

    testWidgets(
      'expanded speed camera shows type source validity and distance',
      (tester) async {
        await tester.pumpWidget(_hud(ValueNotifier(_location(longitude: 0))));
        await tester.tap(find.byKey(const Key('ar-marker-speedCamera')));
        await tester.pumpAndSettle();
        expect(find.text('Fester Blitzer'), findsOneWidget);
        expect(find.text('Community'), findsWidgets);
        expect(find.text('Gültig bis'), findsOneWidget);
        expect(find.text('Entfernung'), findsOneWidget);
      },
    );

    testWidgets('expanded charging station shows navigation actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hud(ValueNotifier(_location(longitude: 0)), warnings: [_charging]),
      );
      await tester.tap(find.byKey(const Key('ar-marker-chargingStation')));
      await tester.pumpAndSettle();
      expect(find.text('Dorthin navigieren'), findsOneWidget);
      expect(find.text('In Karten öffnen'), findsOneWidget);
    });

    testWidgets('expanded Autobahn warning shows source and type', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hud(ValueNotifier(_location(longitude: 0)), warnings: [_roadwork]),
      );
      await tester.tap(find.byKey(const Key('ar-marker-roadwork')));
      await tester.pumpAndSettle();
      expect(find.text('Baustelle'), findsWidgets);
      expect(find.text('Autobahn A3'), findsOneWidget);
    });

    testWidgets('expanded detail updates live distance', (tester) async {
      final location = ValueNotifier(_location(longitude: 0));
      await tester.pumpWidget(_hud(location));
      await tester.tap(find.byKey(const Key('ar-marker-speedCamera')));
      await tester.pumpAndSettle();
      expect(find.text('450 m'), findsWidgets);

      location.value = _location(longitude: 0.002);
      await tester.pump();
      expect(find.text('230 m'), findsWidgets);
    });

    testWidgets('object leaving FOV collapses detail', (tester) async {
      final location = ValueNotifier(_location(longitude: 0, heading: 90));
      await tester.pumpWidget(_hud(location));
      await tester.tap(find.byKey(const Key('ar-marker-speedCamera')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ar-info-detail-card')), findsOneWidget);

      location.value = _location(longitude: 0, heading: 180);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('ar-info-detail-card')), findsNothing);
    });

    testWidgets('compact iPhone layout has no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_hud(ValueNotifier(_location(longitude: 0))));
      await tester.tap(find.byKey(const Key('ar-marker-speedCamera')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text scale has no overflow', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: _hud(ValueNotifier(_location(longitude: 0))),
        ),
      );
      await tester.tap(find.byKey(const Key('ar-marker-speedCamera')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

const _factory = ArInfoObjectFactory();

Widget _hud(
  ValueNotifier<LocationStatus> location, {
  List<HudWarningItem>? warnings,
}) => MaterialApp(
  theme: buildAppTheme(),
  home: HudScreen(
    hudRepository: _FakeHudRepository(warnings ?? [_coordinateWarning]),
    locationRepository: _FakeLocationRepository(location),
    dataSourceRegistry: const _FakeDataSourceRegistry(),
    permissionRepository: _FakePermissionRepository(
      const SensorPermissionStatus(
        camera: SensorPermissionState.denied,
        location: SensorPermissionState.granted,
        motion: SensorPermissionState.denied,
      ),
    ),
    cameraLayerBuilder: (_) =>
        const ColoredBox(key: Key('fake-camera-layer'), color: Colors.black),
  ),
);

LocationStatus _location({required double longitude, int heading = 90}) =>
    LocationStatus(
      speedKph: 50,
      headingDegrees: heading,
      gpsFixStatus: GpsFixStatus.strong,
      isMock: false,
      isSpeedEstimatedFromGps: false,
      latitude: 0,
      longitude: longitude,
      accuracyMeters: 12,
    );

final _coordinateWarning = HudWarningItem(
  id: 'speed-1',
  type: WarningType.speedCamera,
  title: 'Community Blitzer',
  detail: 'Feste Kamera',
  distanceMeters: 999,
  bearingDegrees: 90,
  severity: 5,
  source: 'Community',
  latitude: 0,
  longitude: 0.00405,
  validFrom: DateTime.utc(2026, 5, 29, 8),
  validTo: DateTime.utc(2026, 5, 29, 10),
);

const _charging = HudWarningItem(
  id: 'charge-1',
  type: WarningType.chargingStation,
  title: 'Schnelllader',
  detail: '150-kW-Lader',
  distanceMeters: 1200,
  bearingDegrees: 92,
  severity: 1,
  source: 'Ladenetz',
  latitude: 0,
  longitude: 0.005,
);

const _roadwork = HudWarningItem(
  id: 'road-1',
  type: WarningType.roadwork,
  title: 'Baustelle',
  detail: 'Spurverengung',
  distanceMeters: 800,
  bearingDegrees: 88,
  severity: 3,
  source: 'Autobahn A3',
  roadId: 'A3',
  latitude: 0,
  longitude: 0.003,
);

final _twoWarnings = [_coordinateWarning, _charging];

class _FakeHudRepository implements HudRepository {
  const _FakeHudRepository(this.warnings);

  final List<HudWarningItem> warnings;

  @override
  List<HudWarningItem> getNearbyWarnings() => warnings;
}

class _FakeLocationRepository implements LocationRepository {
  const _FakeLocationRepository(this.status);

  final ValueNotifier<LocationStatus> status;

  @override
  ValueListenable<LocationStatus> get locationStatusListenable => status;
}

class _FakePermissionRepository implements PermissionRepository {
  _FakePermissionRepository(this.permissions);

  final SensorPermissionStatus permissions;

  @override
  ValueListenable<SensorPermissionStatus> get permissionStatusListenable =>
      ValueNotifier(permissions);
}

class _FakeDataSourceRegistry implements DataSourceRegistry {
  const _FakeDataSourceRegistry();

  @override
  List<DataSourceStatus> getRegisteredSources() => const [];
}
