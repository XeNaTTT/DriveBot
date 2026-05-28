import 'dart:async';

import '../../hud/domain/hud_warning_item.dart';
import '../../warnings/data/warning_cache.dart';
import '../../warnings/domain/warning_repository.dart';
import '../../warnings/domain/warning_repository_result.dart';
import '../../warnings/domain/warning_request.dart';
import 'open_meteo_client.dart';

typedef OpenMeteoWeatherFetcher = Future<OpenMeteoDrivingWeather?> Function(
  WarningRequest request,
);

class OpenMeteoWarningRepository implements WarningRepository {
  OpenMeteoWarningRepository({
    required this.fetchWeather,
    this.cache,
    this.timeout = const Duration(seconds: 4),
  });

  factory OpenMeteoWarningRepository.live({
    WarningCache? cache,
    Duration timeout = const Duration(seconds: 4),
  }) {
    final client = OpenMeteoClient();
    return OpenMeteoWarningRepository(
      fetchWeather: client.fetchDrivingWeather,
      cache: cache,
      timeout: timeout,
    );
  }

  final OpenMeteoWeatherFetcher fetchWeather;
  final WarningCache? cache;
  final Duration timeout;

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    final cached = cache?.read(request.cacheKey);
    if (cached != null && cached.hasWarnings) {
      return WarningRepositoryResult.cache(cached.warnings);
    }

    try {
      final weather = await fetchWeather(request).timeout(timeout);
      if (weather == null || !weather.hasDrivingWeather) {
        return const WarningRepositoryResult.empty();
      }

      final warnings = _mapWeather(weather, request);
      if (warnings.isEmpty) return const WarningRepositoryResult.empty();

      final result = WarningRepositoryResult.live(warnings);
      cache?.write(request.cacheKey, result);
      return result;
    } on TimeoutException {
      return const WarningRepositoryResult.failure('open-meteo-timeout');
    } catch (_) {
      return const WarningRepositoryResult.failure('open-meteo-error');
    }
  }

  List<HudWarningItem> _mapWeather(
    OpenMeteoDrivingWeather weather,
    WarningRequest request,
  ) {
    final warnings = <HudWarningItem>[];
    final rainAmount = [
      weather.precipitationMm,
      weather.rainMm,
      weather.showersMm
    ].reduce((a, b) => a > b ? a : b);

    if (rainAmount >= 7) {
      warnings.add(
        _warning(
          request,
          title: 'Starkregen',
          detail: 'Open-Meteo meldet starken Regen nahe deiner Route.',
          distanceMeters: 900,
          severity: 4,
        ),
      );
    } else if (rainAmount > 0) {
      warnings.add(
        _warning(
          request,
          title: 'Regen in der Nähe',
          detail: 'Nasse Fahrbahn laut Live-Wetterdaten wahrscheinlich.',
          distanceMeters: 1200,
          severity: 2,
        ),
      );
    }

    final visibility = weather.visibilityMeters;
    final fogCode = weather.weatherCode == 45 || weather.weatherCode == 48;
    if (fogCode || (visibility != null && visibility < 3000)) {
      warnings.add(
        _warning(
          request,
          title: 'Schlechte Sicht',
          detail: visibility == null
              ? 'Open-Meteo meldet Nebelbedingungen.'
              : 'Sichtweite etwa ${visibility.round()} m.',
          distanceMeters: 700,
          severity: visibility != null && visibility < 1000 ? 4 : 3,
        ),
      );
    }

    if (weather.windSpeedKmh >= 50 || weather.windGustsKmh >= 65) {
      warnings.add(
        _warning(
          request,
          title: 'Starker Wind',
          detail:
              'Wind ${weather.windSpeedKmh.round()} km/h, Böen ${weather.windGustsKmh.round()} km/h.',
          distanceMeters: 1600,
          severity: 3,
        ),
      );
    }

    return warnings;
  }

  HudWarningItem _warning(
    WarningRequest request, {
    required String title,
    required String detail,
    required int distanceMeters,
    required int severity,
  }) {
    return HudWarningItem(
      type: WarningType.weather,
      title: title,
      detail: detail,
      distanceMeters: distanceMeters,
      bearingDegrees: request.headingDegrees,
      severity: severity,
    );
  }
}
