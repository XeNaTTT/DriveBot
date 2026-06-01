import 'dart:async';

import 'package:driveassistant_ar/features/ar/application/ar_info_object_factory.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_projection_mapper.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/location/domain/location_status.dart';
import 'package:driveassistant_ar/features/warnings/data/berlin_traffic_api_client.dart';
import 'package:driveassistant_ar/features/warnings/data/berlin_traffic_warning_source.dart';
import 'package:driveassistant_ar/features/warnings/data/composite_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/mock_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/domain/warning_repository_result.dart';
import 'package:driveassistant_ar/features/warnings/domain/warning_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = WarningRequest(
    latitude: 52.5200,
    longitude: 13.4050,
    headingDegrees: 90,
  );

  test('Berlin GeoJSON roadwork maps to DriveWarning', () async {
    final repository = _repository(_geoJson(subtype: 'Baustelle'));

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.liveApi);
    expect(result.warnings.single.type, WarningType.roadwork);
    expect(result.warnings.single.typeLabel, 'Baustelle');
    expect(result.warnings.single.source, 'Berlin Verkehr');
    expect(result.warnings.single.title, contains('Baustelle'));
    expect(result.warnings.single.detail, contains('Quelle: Berlin Verkehr'));
    expect(result.warnings.single.latitude, closeTo(52.52, 0.0001));
    expect(result.warnings.single.longitude, closeTo(13.415, 0.0001));
  });

  test('Berlin closure maps to high severity warning', () async {
    final repository = _repository(_geoJson(subtype: 'Sperrung'));

    final result = await repository.getWarnings(request);

    expect(result.warnings.single.typeLabel, 'Sperrung');
    expect(result.warnings.single.severity, 5);
  });

  test('entry without coordinates is ignored for AR markers', () async {
    final repository = _repository(_geoJson(withGeometry: false));

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.empty);
    expect(result.warnings, isEmpty);
  });

  test('expired entry is ignored', () async {
    final repository = _repository(
      _geoJson(validTo: '2026-05-01T10:00:00Z'),
      now: () => DateTime.utc(2026, 6),
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.empty);
  });

  test('invalid JSON does not crash', () async {
    final client = BerlinTrafficApiClient(httpGet: (_) async => '{not-json');

    final features = await client.fetchTrafficFeatures();

    expect(features, isEmpty);
  });

  test('network timeout falls back gracefully', () async {
    final repository = CompositeWarningRepository(
      primary: BerlinTrafficWarningSource(
        timeout: const Duration(milliseconds: 1),
        fetchFeatures: () => Completer<List<BerlinTrafficFeature>>().future,
      ),
      fallback: MockWarningRepository(warnings: _fallbackWarnings),
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.fallback);
    expect(result.warnings, _fallbackWarnings);
  });

  test('source label is Berlin Verkehr', () async {
    final repository = _repository(_geoJson());

    final result = await repository.getWarnings(request);

    expect(repository.sourceLabel, 'Berlin Verkehr');
    expect(result.warnings.single.source, 'Berlin Verkehr');
  });

  testWidgets('German labels render', (tester) async {
    final warning = (await _repository(
      _geoJson(subtype: 'Verkehrseinschränkung'),
    ).getWarnings(request)).warnings.single;
    final object = const ArInfoObjectFactory().create(warning, _location);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Text(
            '${object.sourceLabel} ${object.typeLabel} Gültig bis Entfernung Details',
          ),
        ),
      ),
    );

    expect(find.textContaining('Berlin Verkehr'), findsOneWidget);
    expect(find.textContaining('Verkehrseinschränkung'), findsOneWidget);
    expect(find.textContaining('Gültig bis'), findsOneWidget);
    expect(find.textContaining('Entfernung'), findsOneWidget);
    expect(find.textContaining('Details'), findsOneWidget);
  });

  test('warnings outside radius are hidden', () async {
    final repository = _repository(_geoJson(longitude: 13.80));

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.empty);
  });

  test('warnings inside FOV become AR markers', () async {
    final warning = (await _repository(
      _geoJson(),
    ).getWarnings(request)).warnings.single;
    final object = const ArInfoObjectFactory().create(warning, _location);
    final markers = const ArProjectionMapper(
      horizontalFovDegrees: 60,
    ).project(objects: [object], userHeadingDegrees: request.headingDegrees);

    expect(markers, hasLength(1));
    expect(markers.single.infoObject.sourceLabel, 'Berlin Verkehr');
  });

  test('Berlin client uses public endpoints without API keys', () {
    final endpoints = BerlinTrafficApiClient.defaultEndpoints;

    expect(endpoints, isNotEmpty);
    expect(endpoints.every((uri) => uri.scheme == 'https'), isTrue);
    expect(endpoints.every((uri) => uri.query.isEmpty), isTrue);
    expect(endpoints.every((uri) => uri.host == 'api.viz.berlin.de'), isTrue);
  });
}

BerlinTrafficWarningSource _repository(
  String body, {
  DateTime Function()? now,
}) {
  final client = BerlinTrafficApiClient(httpGet: (_) async => body);
  return BerlinTrafficWarningSource(
    fetchFeatures: client.fetchTrafficFeatures,
    now: now ?? () => DateTime.utc(2026, 5, 1),
  );
}

String _geoJson({
  String subtype = 'Baustelle',
  bool withGeometry = true,
  double longitude = 13.415,
  String validTo = '2099-01-01T10:00:00Z',
}) =>
    '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "id": "berlin-1",
        "subtype": "$subtype",
        "street": "Unter den Linden",
        "section": "Brandenburger Tor bis Friedrichstraße",
        "content": "Rechter Fahrstreifen gesperrt.",
        "validity": {
          "from": "2026-05-01T08:00:00Z",
          "to": "$validTo"
        }
      }${withGeometry ? ',"geometry":{"type":"LineString","coordinates":[[$longitude,52.52],[13.416,52.52]]}' : ''}
    }
  ]
}
''';

const _location = LocationStatus(
  speedKph: 30,
  headingDegrees: 90,
  gpsFixStatus: GpsFixStatus.strong,
  isMock: false,
  isSpeedEstimatedFromGps: false,
  latitude: 52.5200,
  longitude: 13.4050,
  accuracyMeters: 10,
);

const _fallbackWarnings = [
  HudWarningItem(
    type: WarningType.notice,
    title: 'Fallback-Hinweis',
    detail: 'Fallback aktiv',
    distanceMeters: 500,
    bearingDegrees: 90,
    severity: 1,
  ),
];
