import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/drive_warning.dart';

typedef BerlinTrafficHttpGet = Future<String> Function(Uri uri);

class BerlinTrafficApiClient {
  BerlinTrafficApiClient({
    List<Uri>? endpoints,
    HttpClient? httpClient,
    BerlinTrafficHttpGet? httpGet,
    this.timeout = const Duration(seconds: 4),
  }) : endpoints = endpoints ?? defaultEndpoints,
       _httpClient = httpClient ?? HttpClient(),
       // Public injection keeps tests decoupled from dart:io HttpClient.
       // ignore: prefer_initializing_formals
       _httpGet = httpGet;

  static final defaultEndpoints = [
    Uri.parse('https://api.viz.berlin.de/daten/baustellen_sperrungen.json'),
    Uri.parse('https://api.viz.berlin.de/tic3/baustellen_sperrungen_tic.json'),
  ];

  final List<Uri> endpoints;
  final HttpClient _httpClient;
  final BerlinTrafficHttpGet? _httpGet;
  final Duration timeout;

  Future<List<BerlinTrafficFeature>> fetchTrafficFeatures() async {
    for (final endpoint in endpoints) {
      final features = await _fetchEndpoint(endpoint);
      if (features.isNotEmpty) return features;
    }
    return const [];
  }

  Future<List<BerlinTrafficFeature>> _fetchEndpoint(Uri endpoint) async {
    try {
      final body =
          await (_httpGet == null ? _defaultGet(endpoint) : _httpGet(endpoint))
              .timeout(timeout);
      final decoded = jsonDecode(body);
      return BerlinTrafficGeoJsonParser.parse(decoded);
    } on TimeoutException {
      rethrow;
    } on FormatException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<String> _defaultGet(Uri uri) async {
    final request = await _httpClient.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) return '{}';
    return utf8.decodeStream(response).timeout(timeout);
  }

  void close() => _httpClient.close(force: true);
}

class BerlinTrafficFeature {
  const BerlinTrafficFeature({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.validFrom,
    this.validTo,
  });

  final String id;
  final DriveWarningKind kind;
  final String title;
  final String description;
  final double? latitude;
  final double? longitude;
  final DateTime? validFrom;
  final DateTime? validTo;

  bool get hasCoordinates => latitude != null && longitude != null;
}

class BerlinTrafficGeoJsonParser {
  const BerlinTrafficGeoJsonParser._();

  static List<BerlinTrafficFeature> parse(Object? decoded) {
    final features = _featureEntries(decoded);
    return features.map(_feature).whereType<BerlinTrafficFeature>().toList();
  }

  static Iterable<Map<String, Object?>> _featureEntries(Object? decoded) {
    final root = _asMap(decoded);
    if (root != null) {
      final features = root['features'];
      if (features is List) {
        return features.map(_asMap).whereType<Map<String, Object?>>();
      }
      final items = root['items'] ?? root['data'];
      if (items is List) {
        return items.map(_asMap).whereType<Map<String, Object?>>();
      }
      return [root];
    }
    if (decoded is List) {
      return decoded.map(_asMap).whereType<Map<String, Object?>>();
    }
    return const [];
  }

  static BerlinTrafficFeature? _feature(Map<String, Object?> feature) {
    final properties = _properties(feature);
    final coordinate =
        _coordinate(feature['geometry']) ?? _directCoordinate(properties);
    final kind = _kind(properties);
    final title = _text(properties, const [
      'title',
      'street',
      'subtype',
      'subject',
      'name',
    ]);
    final section = _text(properties, const ['section', 'location', 'where']);
    final content = _text(properties, const [
      'content',
      'description',
      'contents',
      'reason',
      'message',
    ]);
    final description = [
      if (section.isNotEmpty) section,
      if (content.isNotEmpty) content,
    ].join(' · ');

    return BerlinTrafficFeature(
      id: _text(properties, const ['id', '@id', 'identifier']).isEmpty
          ? '${kind.name}:${coordinate?.$1}:${coordinate?.$2}:$title'
          : _text(properties, const ['id', '@id', 'identifier']),
      kind: kind,
      title: title.isEmpty ? kind.germanLabel : '${kind.germanLabel}: $title',
      description: description.isEmpty ? 'Quelle: Berlin Verkehr' : description,
      latitude: coordinate?.$2,
      longitude: coordinate?.$1,
      validFrom: _date(properties, const [
        'validity.from',
        '@validity.from',
        'validFrom',
        'ValidityPeriodStart',
        'start',
      ]),
      validTo: _date(properties, const [
        'validity.to',
        '@validity.to',
        'validTo',
        'ValidityPeriodEnd',
        'end',
      ]),
    );
  }

  static Map<String, Object?> _properties(Map<String, Object?> feature) {
    final value = _asMap(feature['properties']);
    if (value != null) return value;
    return feature;
  }

  static DriveWarningKind _kind(Map<String, Object?> properties) {
    final explicit = _text(properties, const [
      'subtype',
      'type',
      'icon',
      'category',
    ]).toLowerCase();
    final explicitKind = _kindFromText(explicit);
    if (explicitKind != null) return explicitKind;

    final fallback = _text(properties, const [
      'title',
      'content',
      'description',
    ]).toLowerCase();
    return _kindFromText(fallback) ?? DriveWarningKind.incident;
  }

  static DriveWarningKind? _kindFromText(String text) {
    if (text.contains('sperr')) return DriveWarningKind.closure;
    if (text.contains('baust') || text.contains('bauarbeit')) {
      return DriveWarningKind.roadwork;
    }
    if (text.contains('einschr') || text.contains('störung')) {
      return DriveWarningKind.restriction;
    }
    return null;
  }

  static (double, double)? _coordinate(Object? geometryValue) {
    final geometry = _asMap(geometryValue);
    if (geometry == null) return null;
    final type = _string(geometry['type']).toLowerCase();
    if (type == 'geometrycollection') {
      final geometries = geometry['geometries'];
      if (geometries is List) {
        for (final item in geometries) {
          final coordinate = _coordinate(item);
          if (coordinate != null) return coordinate;
        }
      }
      return null;
    }
    return _firstPosition(geometry['coordinates']);
  }

  static (double, double)? _firstPosition(Object? coordinates) {
    if (coordinates is List && coordinates.length >= 2) {
      final lon = _number(coordinates[0]);
      final lat = _number(coordinates[1]);
      if (lon != null && lat != null) return (lon, lat);
      for (final item in coordinates) {
        final nested = _firstPosition(item);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  static (double, double)? _directCoordinate(Map<String, Object?> properties) {
    final lat = _number(properties['latitude'] ?? properties['lat']);
    final lon = _number(
      properties['longitude'] ?? properties['lon'] ?? properties['lng'],
    );
    if (lat == null || lon == null) return null;
    return (lon, lat);
  }

  static DateTime? _date(Map<String, Object?> properties, List<String> keys) {
    for (final key in keys) {
      final value = _nestedValue(properties, key);
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
    }
    return null;
  }

  static Object? _nestedValue(Map<String, Object?> properties, String key) {
    if (properties.containsKey(key)) {
      return properties[key];
    }
    if (!key.contains('.')) {
      return null;
    }
    Object? current = properties;
    for (final part in key.split('.')) {
      final map = _asMap(current);
      if (map == null) {
        return null;
      }
      current = map[part];
    }
    return current;
  }

  static String _text(Map<String, Object?> properties, List<String> keys) {
    for (final key in keys) {
      final value = _nestedValue(properties, key);
      final text = _string(value).trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static String _string(Object? value) => switch (value) {
    String text => text,
    num number => number.toString(),
    _ => '',
  };

  static double? _number(Object? value) => switch (value) {
    num number when number.isFinite => number.toDouble(),
    String text => double.tryParse(text.replaceAll(',', '.')),
    _ => null,
  };
}
