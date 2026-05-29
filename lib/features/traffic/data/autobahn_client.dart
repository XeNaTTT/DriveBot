import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../warnings/domain/warning_request.dart';

typedef AutobahnHttpGet = Future<String> Function(Uri uri);

enum AutobahnWarningKind { roadwork, warning, closure }

class AutobahnApiClient {
  AutobahnApiClient({
    HttpClient? httpClient,
    AutobahnHttpGet? httpGet,
    this.timeout = const Duration(seconds: 4),
  }) : _httpClient = httpClient ?? HttpClient(),
       // Public injection keeps tests decoupled from dart:io HttpClient.
       // ignore: prefer_initializing_formals
       _httpGet = httpGet;

  static const baseUrl = 'https://verkehr.autobahn.de/o/autobahn/';
  static const _host = 'verkehr.autobahn.de';
  static const _basePath = '/o/autobahn';

  final HttpClient _httpClient;
  final AutobahnHttpGet? _httpGet;
  final Duration timeout;

  Future<List<String>> fetchRoads() async {
    final json = await _getJson(Uri.https(_host, _basePath));
    final roads = json['roads'];
    if (roads is! List) return const [];
    return roads.whereType<String>().toList(growable: false);
  }

  Future<List<AutobahnTrafficItem>> fetchTrafficItems(String roadId) async {
    final services = await Future.wait([
      _fetchService(roadId, AutobahnWarningKind.roadwork, 'roadworks'),
      _fetchService(roadId, AutobahnWarningKind.warning, 'warnings'),
      _fetchService(roadId, AutobahnWarningKind.closure, 'closures'),
    ]);
    return services.expand((items) => items).toList(growable: false);
  }

  Future<List<AutobahnTrafficItem>> _fetchService(
    String roadId,
    AutobahnWarningKind kind,
    String service,
  ) async {
    final uri = Uri.https(_host, '$_basePath/$roadId/services/$service');
    final json = await _getJson(uri);
    return AutobahnTrafficParser.parse(json, roadId: roadId, kind: kind);
  }

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    try {
      final body = await (_httpGet == null ? _defaultGet(uri) : _httpGet(uri))
          .timeout(timeout);
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      return const {};
    } on TimeoutException {
      rethrow;
    } catch (_) {
      return const {};
    }
    return const {};
  }

  Future<String> _defaultGet(Uri uri) async {
    final request = await _httpClient.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return '{}';
    }
    return utf8.decodeStream(response).timeout(timeout);
  }

  void close() => _httpClient.close(force: true);
}

class AutobahnTrafficItem {
  const AutobahnTrafficItem({
    required this.kind,
    required this.roadId,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.validFrom,
    this.validTo,
  });

  final AutobahnWarningKind kind;
  final String roadId;
  final String title;
  final String subtitle;
  final double? latitude;
  final double? longitude;
  final DateTime? validFrom;
  final DateTime? validTo;

  bool get isRoadwork => kind == AutobahnWarningKind.roadwork;
  bool get isClosure => kind == AutobahnWarningKind.closure;
}

class AutobahnClient extends AutobahnApiClient {
  AutobahnClient({super.httpClient, super.httpGet, super.timeout});
}

class AutobahnTrafficParser {
  const AutobahnTrafficParser._();

  static List<AutobahnTrafficItem> parse(
    Map<String, Object?> json, {
    required String roadId,
    required AutobahnWarningKind kind,
  }) {
    final entries = _entries(json, kind);
    return entries
        .map((entry) => _item(entry, roadId: roadId, kind: kind))
        .toList(growable: false);
  }

  static Iterable<Map<String, Object?>> _entries(
    Map<String, Object?> json,
    AutobahnWarningKind kind,
  ) {
    final preferredKey = switch (kind) {
      AutobahnWarningKind.roadwork => 'roadworks',
      AutobahnWarningKind.warning => 'warnings',
      AutobahnWarningKind.closure => 'closures',
    };
    final legacyKey = switch (kind) {
      AutobahnWarningKind.roadwork => 'roadwork',
      AutobahnWarningKind.warning => 'warning',
      AutobahnWarningKind.closure => 'closure',
    };
    final value = json[preferredKey] ?? json[legacyKey] ?? json['items'];
    if (value is! List) return const [];
    return value.whereType<Map<String, Object?>>();
  }

  static AutobahnTrafficItem _item(
    Map<String, Object?> entry, {
    required String roadId,
    required AutobahnWarningKind kind,
  }) {
    final coordinate = _coordinate(entry);
    final title = _text(entry, const [
      'title',
      'shortTitle',
      'identifier',
      'subtitle',
    ]);
    final subtitle = _text(entry, const [
      'subtitle',
      'description',
      'longDescription',
      'routeRecommendation',
    ]);

    return AutobahnTrafficItem(
      kind: kind,
      roadId: _text(entry, const ['roadId', 'road', 'roadName']).isEmpty
          ? roadId
          : _text(entry, const ['roadId', 'road', 'roadName']),
      title: title.isEmpty ? _defaultTitle(kind) : title,
      subtitle: subtitle.isEmpty ? 'Quelle: Autobahn · Live-Daten' : subtitle,
      latitude: coordinate.$1,
      longitude: coordinate.$2,
      validFrom: _date(entry, const ['startTimestamp', 'validFrom', 'start']),
      validTo: _date(entry, const ['endTimestamp', 'validTo', 'end']),
    );
  }

  static (double?, double?) _coordinate(Map<String, Object?> entry) {
    final direct = (
      _number(entry['latitude'] ?? entry['lat']),
      _number(entry['longitude'] ?? entry['lon'] ?? entry['long']),
    );
    if (direct.$1 != null && direct.$2 != null) return direct;

    for (final key in const [
      'coordinate',
      'coordinates',
      'point',
      'position',
    ]) {
      final value = entry[key];
      if (value is Map<String, Object?>) {
        final coordinate = (
          _number(value['lat'] ?? value['latitude']),
          _number(value['long'] ?? value['lon'] ?? value['longitude']),
        );
        if (coordinate.$1 != null && coordinate.$2 != null) return coordinate;
      }
      if (value is List && value.length >= 2) {
        final first = _number(value[0]);
        final second = _number(value[1]);
        if (first != null && second != null) return (first, second);
      }
    }
    return (null, null);
  }

  static String _text(Map<String, Object?> entry, List<String> keys) {
    for (final key in keys) {
      final value = entry[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is List) {
        final parts = value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty);
        if (parts.isNotEmpty) return parts.join(' ');
      }
    }
    return '';
  }

  static double? _number(Object? value) {
    return switch (value) {
      num number when number.isFinite => number.toDouble(),
      String text => double.tryParse(text.replaceAll(',', '.')),
      _ => null,
    };
  }

  static DateTime? _date(Map<String, Object?> entry, List<String> keys) {
    for (final key in keys) {
      final value = entry[key];
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
    }
    return null;
  }

  static String _defaultTitle(AutobahnWarningKind kind) => switch (kind) {
    AutobahnWarningKind.roadwork => 'Baustelle',
    AutobahnWarningKind.closure => 'Sperrung',
    AutobahnWarningKind.warning => 'Verkehrsmeldung',
  };
}

class AutobahnWarningSource {
  const AutobahnWarningSource({
    required this.client,
    this.roadIds = const ['A3'],
  });

  final AutobahnApiClient client;
  final List<String> roadIds;

  Future<List<AutobahnTrafficItem>> fetch(WarningRequest request) async {
    final items = <AutobahnTrafficItem>[];
    for (final roadId in roadIds) {
      items.addAll(await client.fetchTrafficItems(roadId));
    }
    return items;
  }
}
