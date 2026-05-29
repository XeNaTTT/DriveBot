import 'dart:async';

import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/traffic/data/autobahn_client.dart';
import 'package:driveassistant_ar/features/traffic/data/autobahn_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/composite_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/mock_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/warning_cache.dart';
import 'package:driveassistant_ar/features/warnings/domain/warning_repository_result.dart';
import 'package:driveassistant_ar/features/warnings/domain/warning_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = WarningRequest(
    latitude: 50.1109,
    longitude: 8.6821,
    headingDegrees: 90,
  );

  test('roadworks maps to DriveWarning with Autobahn metadata', () async {
    final repository = AutobahnWarningRepository(
      fetchTrafficItems: (_) async => [
        _trafficItem(
          kind: AutobahnWarningKind.roadwork,
          title: 'Spurverengung',
          longitude: 8.6921,
        ),
      ],
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.liveApi);
    expect(result.warnings.single.type, WarningType.roadwork);
    expect(result.warnings.single.source, 'Autobahn');
    expect(result.warnings.single.roadId, 'A3');
    expect(result.warnings.single.title, contains('Baustelle'));
    expect(result.warnings.single.detail, contains('Quelle: Autobahn'));
    expect(result.warnings.single.latitude, 50.1109);
    expect(result.warnings.single.longitude, 8.6921);
    expect(result.warnings.single.distanceMeters, greaterThan(0));
  });

  test('warnings and closures map to German traffic labels', () async {
    final repository = AutobahnWarningRepository(
      fetchTrafficItems: (_) async => [
        _trafficItem(
          kind: AutobahnWarningKind.warning,
          title: 'Gefahr durch Gegenstände',
          longitude: 8.6921,
        ),
        _trafficItem(
          kind: AutobahnWarningKind.closure,
          title: 'Ausfahrt gesperrt',
          longitude: 8.7021,
        ),
      ],
    );

    final result = await repository.getWarnings(request);

    expect(result.warnings.first.title, contains('Verkehrsmeldung'));
    expect(result.warnings.last.title, contains('Sperrung'));
    expect(result.warnings.last.severity, 5);
  });

  test('invalid JSON does not crash', () async {
    final client = AutobahnApiClient(httpGet: (_) async => '{not-json');

    final items = await client.fetchTrafficItems('A3');

    expect(items, isEmpty);
  });

  test('network error falls back through composite repository', () async {
    final repository = CompositeWarningRepository(
      primary: AutobahnWarningRepository(
        fetchTrafficItems: (_) => throw StateError('offline'),
      ),
      fallback: MockWarningRepository(warnings: _fallbackWarnings),
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.fallback);
    expect(result.warnings, _fallbackWarnings);
  });

  test('API timeout falls back through composite repository', () async {
    final repository = CompositeWarningRepository(
      primary: AutobahnWarningRepository(
        timeout: const Duration(milliseconds: 1),
        fetchTrafficItems: (_) => Completer<List<AutobahnTrafficItem>>().future,
      ),
      fallback: MockWarningRepository(warnings: _fallbackWarnings),
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.fallback);
  });

  test('no current location falls back through composite repository', () async {
    final repository = CompositeWarningRepository(
      primary: AutobahnWarningRepository(
        fetchTrafficItems: (_) async => [_trafficItem(longitude: 8.6921)],
      ),
      fallback: MockWarningRepository(warnings: _fallbackWarnings),
    );

    final result = await repository.getWarnings(
      const WarningRequest.fallback(),
    );

    expect(result.source, WarningDataSource.fallback);
  });

  test('entries without coordinates are ignored', () async {
    final repository = AutobahnWarningRepository(
      fetchTrafficItems: (_) async => [_trafficItem(latitude: null)],
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.empty);
    expect(result.warnings, isEmpty);
  });

  test('entries outside radius are ignored', () async {
    final repository = AutobahnWarningRepository(
      fetchTrafficItems: (_) async => [_trafficItem(longitude: 8.80)],
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.empty);
    expect(result.warnings, isEmpty);
  });

  test('entries outside AR field-of-view are ignored', () async {
    final repository = AutobahnWarningRepository(
      fetchTrafficItems: (_) async => [_trafficItem(latitude: 50.1209)],
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.empty);
  });

  test('German source label is shown for live Autobahn warnings', () async {
    final repository = CompositeWarningRepository(
      primary: AutobahnWarningRepository(
        fetchTrafficItems: (_) async => [_trafficItem(longitude: 8.6921)],
      ),
      fallback: MockWarningRepository(warnings: _fallbackWarnings),
    );

    final result = await repository.getWarnings(request);

    expect(result.source.userFacingGermanLabel, 'Live-Daten');
    expect(repository.dataSourceLabel, 'Live-Daten');
    expect(result.warnings.single.detail, contains('Quelle: Autobahn'));
  });

  test(
    'Autobahn API client fetches roadworks, warnings, and closures',
    () async {
      final requestedPaths = <String>[];
      final client = AutobahnApiClient(
        httpGet: (uri) async {
          requestedPaths.add(uri.path);
          return switch (uri.path) {
            '/o/autobahn/A3/services/roadworks' => _serviceJson('roadworks'),
            '/o/autobahn/A3/services/warnings' => _serviceJson('warnings'),
            '/o/autobahn/A3/services/closures' => _serviceJson('closures'),
            _ => '{}',
          };
        },
      );
      final source = AutobahnWarningSource(client: client);

      final items = await source.fetch(request);

      expect(items, hasLength(3));
      expect(requestedPaths, contains('/o/autobahn/A3/services/roadworks'));
      expect(requestedPaths, contains('/o/autobahn/A3/services/warnings'));
      expect(requestedPaths, contains('/o/autobahn/A3/services/closures'));
    },
  );

  test('Autobahn repository uses in-memory cache', () async {
    var calls = 0;
    final repository = AutobahnWarningRepository(
      cache: InMemoryWarningCache(),
      fetchTrafficItems: (_) async {
        calls += 1;
        return [_trafficItem(longitude: 8.6921)];
      },
    );

    final first = await repository.getWarnings(request);
    final second = await repository.getWarnings(request);

    expect(first.source, WarningDataSource.liveApi);
    expect(second.source, WarningDataSource.cache);
    expect(calls, 1);
  });
}

AutobahnTrafficItem _trafficItem({
  AutobahnWarningKind kind = AutobahnWarningKind.roadwork,
  String title = 'A3 Baustelle',
  double? latitude = 50.1109,
  double? longitude = 8.6921,
}) {
  return AutobahnTrafficItem(
    kind: kind,
    roadId: 'A3',
    title: title,
    subtitle: 'Rechter Fahrstreifen gesperrt.',
    latitude: latitude,
    longitude: longitude,
    validFrom: DateTime.utc(2026, 5, 29, 8),
    validTo: DateTime.utc(2026, 5, 29, 12),
  );
}

String _serviceJson(String key) =>
    '''
{
  "$key": [
    {
      "title": "A3 Meldung",
      "subtitle": "Testmeldung",
      "coordinate": {"lat": "50.1109", "long": "8.6921"}
    }
  ]
}
''';

const _fallbackWarnings = [
  HudWarningItem(
    type: WarningType.roadwork,
    title: 'Roadwork Zone',
    detail: 'Lane narrowing in 1.2 km',
    distanceMeters: 1200,
    bearingDegrees: 105,
    severity: 3,
  ),
];
