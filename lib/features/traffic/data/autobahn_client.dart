import 'dart:convert';
import 'dart:io';

class AutobahnTrafficItem {
  const AutobahnTrafficItem({
    required this.title,
    required this.detail,
    required this.isRoadwork,
  });

  final String title;
  final String detail;
  final bool isRoadwork;
}

class AutobahnClient {
  AutobahnClient({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Future<List<AutobahnTrafficItem>> fetchTrafficItems(String roadId) async {
    final roadworks = await _fetchService(roadId, 'roadworks');
    final warnings = await _fetchService(roadId, 'warning');
    return [...roadworks, ...warnings];
  }

  Future<List<AutobahnTrafficItem>> _fetchService(
    String roadId,
    String service,
  ) async {
    final uri = Uri.https(
      'verkehr.autobahn.de',
      '/o/autobahn/$roadId/services/$service',
    );
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body);
    if (json is! Map<String, Object?>) return const [];

    return AutobahnTrafficParser.parse(json,
        isRoadwork: service == 'roadworks');
  }

  void close() => _httpClient.close(force: true);
}

class AutobahnTrafficParser {
  const AutobahnTrafficParser._();

  static List<AutobahnTrafficItem> parse(
    Map<String, Object?> json, {
    required bool isRoadwork,
  }) {
    final entries = _entries(json, isRoadwork: isRoadwork);
    return entries.map((entry) => _item(entry, isRoadwork)).toList();
  }

  static Iterable<Map<String, Object?>> _entries(
    Map<String, Object?> json, {
    required bool isRoadwork,
  }) {
    final preferredKey = isRoadwork ? 'roadworks' : 'warning';
    final fallbackKey = isRoadwork ? 'roadwork' : 'warnings';
    final value = json[preferredKey] ?? json[fallbackKey] ?? json['items'];
    if (value is! List) return const [];

    return value.whereType<Map<String, Object?>>();
  }

  static AutobahnTrafficItem _item(
    Map<String, Object?> entry,
    bool isRoadwork,
  ) {
    final title = _text(entry, const [
      'title',
      'subtitle',
      'shortTitle',
      'identifier',
    ]);
    final detail = _text(entry, const [
      'description',
      'longDescription',
      'subtitle',
      'routeRecommendation',
    ]);

    return AutobahnTrafficItem(
      title: title.isEmpty
          ? (isRoadwork ? 'Autobahn-Baustelle' : 'Autobahn-Warnung')
          : title,
      detail: detail.isEmpty ? 'Live-Verkehrslage der Autobahn.' : detail,
      isRoadwork: isRoadwork,
    );
  }

  static String _text(Map<String, Object?> entry, List<String> keys) {
    for (final key in keys) {
      final value = entry[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}
