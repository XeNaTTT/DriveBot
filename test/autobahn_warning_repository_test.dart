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
  const request = WarningRequest.fallback();

  test('maps Autobahn roadworks and warnings to HUD warnings', () async {
    final repository = AutobahnWarningRepository(
      fetchTrafficItems: (_) async => const [
        AutobahnTrafficItem(
          title: 'A3 Roadwork',
          detail: 'Lane narrowing between exits.',
          isRoadwork: true,
        ),
        AutobahnTrafficItem(
          title: 'Traffic Hazard',
          detail: 'Slow traffic ahead.',
          isRoadwork: false,
        ),
      ],
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.liveApi);
    expect(result.warnings.first.type, WarningType.roadwork);
    expect(result.warnings.last.type, WarningType.speedLimit);
  });

  test('API failure falls back through composite repository', () async {
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

  test('empty API response falls back through composite repository', () async {
    final repository = CompositeWarningRepository(
      primary: AutobahnWarningRepository(
        fetchTrafficItems: (_) async => const [],
      ),
      fallback: MockWarningRepository(warnings: _fallbackWarnings),
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.fallback);
    expect(result.warnings, _fallbackWarnings);
  });

  test('timeout falls back through composite repository', () async {
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

  test('Autobahn repository uses in-memory cache', () async {
    var calls = 0;
    final repository = AutobahnWarningRepository(
      cache: InMemoryWarningCache(),
      fetchTrafficItems: (_) async {
        calls += 1;
        return const [
          AutobahnTrafficItem(
            title: 'A3 Roadwork',
            detail: 'Lane narrowing.',
            isRoadwork: true,
          ),
        ];
      },
    );

    final first = await repository.getWarnings(request);
    final second = await repository.getWarnings(request);

    expect(first.source, WarningDataSource.liveApi);
    expect(second.source, WarningDataSource.cache);
    expect(calls, 1);
  });

  test('parses Autobahn JSON safely', () {
    final items = AutobahnTrafficParser.parse({
      'roadworks': [
        {
          'title': 'A3 Baustelle',
          'description': 'Rechter Fahrstreifen gesperrt.',
        },
      ],
    }, isRoadwork: true);

    expect(items.single.title, 'A3 Baustelle');
    expect(items.single.isRoadwork, isTrue);
  });
}

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
