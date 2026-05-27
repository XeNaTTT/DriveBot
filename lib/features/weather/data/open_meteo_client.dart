import 'dart:convert';
import 'dart:io';

import '../../warnings/domain/warning_request.dart';

class OpenMeteoDrivingWeather {
  const OpenMeteoDrivingWeather({
    required this.precipitationMm,
    required this.rainMm,
    required this.showersMm,
    required this.weatherCode,
    required this.windSpeedKmh,
    required this.windGustsKmh,
    required this.visibilityMeters,
  });

  final double precipitationMm;
  final double rainMm;
  final double showersMm;
  final int? weatherCode;
  final double windSpeedKmh;
  final double windGustsKmh;
  final double? visibilityMeters;

  bool get hasDrivingWeather =>
      precipitationMm > 0 ||
      rainMm > 0 ||
      showersMm > 0 ||
      windSpeedKmh >= 45 ||
      windGustsKmh >= 60 ||
      (visibilityMeters != null && visibilityMeters! < 3000) ||
      weatherCode == 45 ||
      weatherCode == 48;
}

class OpenMeteoClient {
  OpenMeteoClient({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Future<OpenMeteoDrivingWeather?> fetchDrivingWeather(
    WarningRequest request,
  ) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': request.latitude.toString(),
      'longitude': request.longitude.toString(),
      'current':
          'precipitation,rain,showers,weather_code,wind_speed_10m,wind_gusts_10m',
      'hourly': 'visibility',
      'forecast_days': '1',
      'timezone': 'auto',
    });

    final httpRequest = await _httpClient.getUrl(uri);
    final response = await httpRequest.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body);
    if (json is! Map<String, Object?>) return null;

    return OpenMeteoDrivingWeatherParser.parse(json);
  }

  void close() => _httpClient.close(force: true);
}

class OpenMeteoDrivingWeatherParser {
  const OpenMeteoDrivingWeatherParser._();

  static OpenMeteoDrivingWeather? parse(Map<String, Object?> json) {
    final current = json['current'];
    if (current is! Map<String, Object?>) return null;

    final hourly = json['hourly'];
    final visibility = hourly is Map<String, Object?>
        ? _firstNumber(hourly['visibility'])
        : null;

    return OpenMeteoDrivingWeather(
      precipitationMm: _number(current['precipitation']),
      rainMm: _number(current['rain']),
      showersMm: _number(current['showers']),
      weatherCode: _int(current['weather_code']),
      windSpeedKmh: _number(current['wind_speed_10m']),
      windGustsKmh: _number(current['wind_gusts_10m']),
      visibilityMeters: visibility,
    );
  }

  static double _number(Object? value) {
    return switch (value) {
      num number => number.toDouble(),
      _ => 0,
    };
  }

  static double? _firstNumber(Object? value) {
    if (value is List && value.isNotEmpty && value.first is num) {
      return (value.first as num).toDouble();
    }
    return null;
  }

  static int? _int(Object? value) {
    return switch (value) {
      int number => number,
      num number => number.toInt(),
      _ => null,
    };
  }
}
