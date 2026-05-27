import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/warnings/data/api_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/composite_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/mock_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/warning_cache.dart';
import 'package:driveassistant_ar/features/warnings/data/warning_mapper.dart';
import 'package:driveassistant_ar/features/warnings/domain/warning_repository_result.dart';
import 'package:driveassistant_ar/features/warnings/domain/warning_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = WarningRequest.fallback();

  test('API success maps payloads to HUD warnings', () async {
    final repository = ApiWarningRepository(
      client: (_) async => const [
        ApiWarningPayload(
          type: 'roadwork',
          title: 'Lane closure',
          detail: 'Right lane closed ahead',
          distanceMeters: 800,
          bearingDegrees: 95,
          severity: 4,
        ),
      ],
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.liveApi);
    expect(result.warnings.single.type, WarningType.roadwork);
    expect(result.warnings.single.title, 'Lane closure');
  });

  test('API failure falls back through composite repository', () async {
    final repository = CompositeWarningRepository(
      primary: ApiWarningRepository(client: (_) => throw StateError('offline')),
      fallback: MockWarningRepository(warnings: _fallbackWarnings),
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.fallback);
    expect(result.warnings, _fallbackWarnings);
    expect(repository.getNearbyWarnings(), _fallbackWarnings);
  });

  test('empty API response falls back through composite repository', () async {
    final repository = CompositeWarningRepository(
      primary: ApiWarningRepository(client: (_) async => const []),
      fallback: MockWarningRepository(warnings: _fallbackWarnings),
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.fallback);
    expect(result.warnings, _fallbackWarnings);
  });

  test('API repository returns cached warnings without second client call',
      () async {
    var calls = 0;
    final repository = ApiWarningRepository(
      cache: InMemoryWarningCache(),
      client: (_) async {
        calls += 1;
        return const [
          ApiWarningPayload(
            type: 'weather',
            title: 'Rain',
            detail: 'Wet road surface',
            distanceMeters: 1500,
            bearingDegrees: 10,
            severity: 2,
          ),
        ];
      },
    );

    final first = await repository.getWarnings(request);
    final second = await repository.getWarnings(request);

    expect(first.source, WarningDataSource.liveApi);
    expect(second.source, WarningDataSource.cache);
    expect(second.warnings.single.title, 'Rain');
    expect(calls, 1);
  });
}

const _fallbackWarnings = [
  HudWarningItem(
    type: WarningType.speedLimit,
    title: 'Speed Limit 80 km/h',
    detail: 'Zone starts in 300 m',
    distanceMeters: 300,
    bearingDegrees: 55,
    severity: 5,
  ),
];
