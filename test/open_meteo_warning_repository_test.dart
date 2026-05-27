import 'dart:async';

import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/weather/data/open_meteo_client.dart';
import 'package:driveassistant_ar/features/weather/data/open_meteo_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/composite_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/mock_warning_repository.dart';
import 'package:driveassistant_ar/features/warnings/data/warning_cache.dart';
import 'package:driveassistant_ar/features/warnings/domain/warning_repository_result.dart';
import 'package:driveassistant_ar/features/warnings/domain/warning_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = WarningRequest.fallback();

  test('maps Open-Meteo rain, visibility, and wind to warnings', () async {
    final repository = OpenMeteoWarningRepository(
      fetchWeather: (_) async => const OpenMeteoDrivingWeather(
        precipitationMm: 8,
        rainMm: 8,
        showersMm: 0,
        weatherCode: 45,
        windSpeedKmh: 52,
        windGustsKmh: 70,
        visibilityMeters: 800,
      ),
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.liveApi);
    expect(result.warnings.map((warning) => warning.title), [
      'Heavy Rain',
      'Low Visibility',
      'Strong Wind',
    ]);
    expect(
      result.warnings.every((warning) => warning.type == WarningType.weather),
      isTrue,
    );
  });

  test('timeout falls back through composite repository', () async {
    final repository = CompositeWarningRepository(
      primary: OpenMeteoWarningRepository(
        timeout: const Duration(milliseconds: 1),
        fetchWeather: (_) => Completer<OpenMeteoDrivingWeather?>().future,
      ),
      fallback: MockWarningRepository(warnings: _fallbackWarnings),
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.fallback);
    expect(result.warnings, _fallbackWarnings);
    expect(repository.dataSourceLabel, 'Fallback data');
  });

  test('empty Open-Meteo response falls back through composite repository',
      () async {
    final repository = CompositeWarningRepository(
      primary: OpenMeteoWarningRepository(
        fetchWeather: (_) async => const OpenMeteoDrivingWeather(
          precipitationMm: 0,
          rainMm: 0,
          showersMm: 0,
          weatherCode: 0,
          windSpeedKmh: 8,
          windGustsKmh: 12,
          visibilityMeters: 10000,
        ),
      ),
      fallback: MockWarningRepository(warnings: _fallbackWarnings),
    );

    final result = await repository.getWarnings(request);

    expect(result.source, WarningDataSource.fallback);
    expect(result.warnings, _fallbackWarnings);
  });

  test('Open-Meteo result uses in-memory cache', () async {
    var calls = 0;
    final repository = OpenMeteoWarningRepository(
      cache: InMemoryWarningCache(),
      fetchWeather: (_) async {
        calls += 1;
        return const OpenMeteoDrivingWeather(
          precipitationMm: 1,
          rainMm: 1,
          showersMm: 0,
          weatherCode: 61,
          windSpeedKmh: 12,
          windGustsKmh: 20,
          visibilityMeters: 9000,
        );
      },
    );

    final first = await repository.getWarnings(request);
    final second = await repository.getWarnings(request);

    expect(first.source, WarningDataSource.liveApi);
    expect(second.source, WarningDataSource.cache);
    expect(calls, 1);
  });

  test('parses Open-Meteo JSON safely', () {
    final weather = OpenMeteoDrivingWeatherParser.parse({
      'current': {
        'precipitation': 2.5,
        'rain': 1.0,
        'showers': 0,
        'weather_code': 61,
        'wind_speed_10m': 18,
        'wind_gusts_10m': 33,
      },
      'hourly': {
        'visibility': [2500],
      },
    });

    expect(weather?.rainMm, 1.0);
    expect(weather?.visibilityMeters, 2500);
  });
}

const _fallbackWarnings = [
  HudWarningItem(
    type: WarningType.weather,
    title: 'Weather Warning',
    detail: 'Heavy rain segment in 2.4 km',
    distanceMeters: 2400,
    bearingDegrees: 12,
    severity: 3,
  ),
];
