import 'dart:async';
import 'dart:math' as math;

import '../../hud/domain/hud_warning_item.dart';
import '../../warnings/data/warning_cache.dart';
import '../../warnings/domain/warning_repository.dart';
import '../../warnings/domain/warning_repository_result.dart';
import '../../warnings/domain/warning_request.dart';
import 'autobahn_client.dart';

typedef AutobahnTrafficFetcher =
    Future<List<AutobahnTrafficItem>> Function(WarningRequest request);

class AutobahnWarningRepository implements WarningRepository {
  AutobahnWarningRepository({
    required this.fetchTrafficItems,
    this.defaultRoadId = 'A3',
    this.cache,
    this.timeout = const Duration(seconds: 4),
    this.radiusMeters = 5000,
    this.horizontalFovDegrees = 60,
  });

  factory AutobahnWarningRepository.live({
    String defaultRoadId = 'A3',
    WarningCache? cache,
    Duration timeout = const Duration(seconds: 4),
  }) {
    final client = AutobahnApiClient(timeout: timeout);
    final source = AutobahnWarningSource(
      client: client,
      roadIds: [defaultRoadId],
    );
    return AutobahnWarningRepository(
      fetchTrafficItems: source.fetch,
      defaultRoadId: defaultRoadId,
      cache: cache,
      timeout: timeout,
    );
  }

  final AutobahnTrafficFetcher fetchTrafficItems;
  final String defaultRoadId;
  final WarningCache? cache;
  final Duration timeout;
  final int radiusMeters;
  final double horizontalFovDegrees;

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    if (!request.hasCurrentLocation) {
      return const WarningRepositoryResult.failure('autobahn-no-location');
    }

    final cacheKey = '${request.cacheKey}:$defaultRoadId';
    final cached = cache?.read(cacheKey);
    if (cached != null && cached.hasWarnings) {
      return WarningRepositoryResult.cache(cached.warnings);
    }

    try {
      final items = await fetchTrafficItems(request).timeout(timeout);
      final warnings =
          items
              .map((item) => _mapItem(item, request))
              .whereType<HudWarningItem>()
              .toList(growable: false)
            ..sort(_sortWarnings(request));

      if (warnings.isEmpty) return const WarningRepositoryResult.empty();

      final result = WarningRepositoryResult.live(warnings.take(4).toList());
      cache?.write(cacheKey, result);
      return result;
    } on TimeoutException {
      return const WarningRepositoryResult.failure('autobahn-api-timeout');
    } catch (_) {
      return const WarningRepositoryResult.failure('autobahn-api-error');
    }
  }

  HudWarningItem? _mapItem(AutobahnTrafficItem item, WarningRequest request) {
    final latitude = item.latitude;
    final longitude = item.longitude;
    if (latitude == null || longitude == null) return null;

    final distance = _distanceMeters(
      request.latitude,
      request.longitude,
      latitude,
      longitude,
    ).round();
    if (distance > radiusMeters) return null;

    final bearing = _bearingDegrees(
      request.latitude,
      request.longitude,
      latitude,
      longitude,
    ).round();
    final relativeBearing = _relativeBearing(bearing, request.headingDegrees);
    if (relativeBearing.abs() > horizontalFovDegrees / 2) return null;

    return HudWarningItem(
      type: _type(item.kind),
      title: _localizedTitle(item),
      detail: _detail(item),
      distanceMeters: distance,
      bearingDegrees: bearing,
      severity: _severity(item.kind),
      source: 'Autobahn',
      roadId: item.roadId,
      latitude: latitude,
      longitude: longitude,
      validFrom: item.validFrom,
      validTo: item.validTo,
    );
  }

  Comparator<HudWarningItem> _sortWarnings(WarningRequest request) {
    return (a, b) {
      final aAhead = _isAhead(a.bearingDegrees, request.headingDegrees);
      final bAhead = _isAhead(b.bearingDegrees, request.headingDegrees);
      if (aAhead != bAhead) return aAhead ? -1 : 1;
      return a.distanceMeters.compareTo(b.distanceMeters);
    };
  }

  bool _isAhead(int bearingDegrees, int headingDegrees) {
    return _relativeBearing(bearingDegrees, headingDegrees).abs() <= 90;
  }

  String _localizedTitle(AutobahnTrafficItem item) {
    final prefix = switch (item.kind) {
      AutobahnWarningKind.roadwork => 'Baustelle',
      AutobahnWarningKind.closure => 'Sperrung',
      AutobahnWarningKind.warning => 'Verkehrsmeldung',
    };
    if (item.title == prefix) return '${item.roadId} · $prefix';
    return '${item.roadId} · $prefix: ${item.title}';
  }

  String _detail(AutobahnTrafficItem item) {
    final validity = _validity(item);
    final parts = [
      'Quelle: Autobahn',
      item.subtitle,
      if (validity.isNotEmpty) validity,
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(' · ');
  }

  String _validity(AutobahnTrafficItem item) {
    if (item.validFrom == null && item.validTo == null) return '';
    final from = item.validFrom == null ? null : _dateLabel(item.validFrom!);
    final to = item.validTo == null ? null : _dateLabel(item.validTo!);
    return switch ((from, to)) {
      (String from, String to) => 'gültig $from–$to',
      (String from, null) => 'gültig ab $from',
      (null, String to) => 'gültig bis $to',
      _ => '',
    };
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute';
  }

  WarningType _type(AutobahnWarningKind kind) => switch (kind) {
    AutobahnWarningKind.roadwork => WarningType.roadwork,
    AutobahnWarningKind.closure => WarningType.notice,
    AutobahnWarningKind.warning => WarningType.notice,
  };

  int _severity(AutobahnWarningKind kind) => switch (kind) {
    AutobahnWarningKind.closure => 5,
    AutobahnWarningKind.warning => 4,
    AutobahnWarningKind.roadwork => 3,
  };

  double _distanceMeters(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _radians(endLat - startLat);
    final dLon = _radians(endLon - startLon);
    final lat1 = _radians(startLat);
    final lat2 = _radians(endLat);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  int _bearingDegrees(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    final lat1 = _radians(startLat);
    final lat2 = _radians(endLat);
    final dLon = _radians(endLon - startLon);
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return ((math.atan2(y, x) * 180 / math.pi) + 360).round() % 360;
  }

  double _relativeBearing(int bearingDegrees, int headingDegrees) {
    var normalized = (bearingDegrees - headingDegrees) % 360;
    if (normalized > 180) normalized -= 360;
    if (normalized < -180) normalized += 360;
    return normalized.toDouble();
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
