import 'dart:async';
import 'dart:math' as math;

import '../domain/drive_warning.dart';
import '../domain/warning_repository.dart';
import '../domain/warning_repository_result.dart';
import '../domain/warning_request.dart';
import '../domain/warning_source.dart';
import 'berlin_traffic_api_client.dart';
import 'warning_cache.dart';

typedef BerlinTrafficFeatureFetcher =
    Future<List<BerlinTrafficFeature>> Function();

class BerlinTrafficWarningSource implements WarningSource, WarningRepository {
  BerlinTrafficWarningSource({
    required this.fetchFeatures,
    this.cache,
    this.timeout = const Duration(seconds: 4),
    this.radiusMeters = 10000,
    this.horizontalFovDegrees = 60,
    this.maxWarnings = 4,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  factory BerlinTrafficWarningSource.live({
    WarningCache? cache,
    Duration timeout = const Duration(seconds: 4),
  }) {
    final client = BerlinTrafficApiClient(timeout: timeout);
    return BerlinTrafficWarningSource(
      fetchFeatures: client.fetchTrafficFeatures,
      cache: cache,
      timeout: timeout,
    );
  }

  static const berlinSourceLabel = 'Berlin Verkehr';

  final BerlinTrafficFeatureFetcher fetchFeatures;
  final WarningCache? cache;
  final Duration timeout;
  final int radiusMeters;
  final double horizontalFovDegrees;
  final int maxWarnings;
  final DateTime Function() _now;

  @override
  String get sourceLabel => berlinSourceLabel;

  @override
  Future<List<DriveWarning>> loadWarnings(WarningRequest request) async {
    if (!request.hasCurrentLocation) return const [];
    final features = await fetchFeatures().timeout(timeout);
    return _mapFeatures(features, request);
  }

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    if (!request.hasCurrentLocation) {
      return const WarningRepositoryResult.failure(
        'berlin-traffic-no-location',
      );
    }

    final cached = cache?.read(request.cacheKey);
    if (cached != null && cached.hasWarnings) {
      return WarningRepositoryResult.cache(cached.warnings);
    }

    try {
      final driveWarnings = await loadWarnings(request);
      if (driveWarnings.isEmpty) return const WarningRepositoryResult.empty();

      final hudWarnings = driveWarnings
          .map((warning) => warning.toHudWarning())
          .toList(growable: false);
      final result = WarningRepositoryResult.live(hudWarnings);
      cache?.write(request.cacheKey, result);
      return result;
    } on TimeoutException {
      return const WarningRepositoryResult.failure('berlin-traffic-timeout');
    } catch (_) {
      return const WarningRepositoryResult.failure('berlin-traffic-error');
    }
  }

  List<DriveWarning> _mapFeatures(
    List<BerlinTrafficFeature> features,
    WarningRequest request,
  ) {
    final warnings =
        features
            .map((feature) => _mapFeature(feature, request))
            .whereType<DriveWarning>()
            .toList(growable: false)
          ..sort(_sortWarnings);
    return warnings.take(maxWarnings).toList(growable: false);
  }

  DriveWarning? _mapFeature(
    BerlinTrafficFeature feature,
    WarningRequest request,
  ) {
    final latitude = feature.latitude;
    final longitude = feature.longitude;
    if (latitude == null || longitude == null) return null;
    if (feature.validTo != null && feature.validTo!.isBefore(_now())) {
      return null;
    }

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
    );
    final relativeBearing = _relativeBearing(bearing, request.headingDegrees);
    if (relativeBearing.abs() > horizontalFovDegrees / 2) return null;

    return DriveWarning(
      id: 'berlin:${feature.id}',
      kind: feature.kind,
      title: feature.title,
      description: _description(feature),
      sourceLabel: sourceLabel,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distance,
      bearingDegrees: bearing,
      severity: _severity(feature.kind),
      validFrom: feature.validFrom,
      validTo: feature.validTo,
    );
  }

  Comparator<DriveWarning> get _sortWarnings => (a, b) {
    final priority = a.kind.priority.compareTo(b.kind.priority);
    if (priority != 0) return priority;
    return a.distanceMeters.compareTo(b.distanceMeters);
  };

  String _description(BerlinTrafficFeature feature) {
    final parts = [
      'Quelle: $sourceLabel',
      feature.description,
      if (feature.validTo != null) 'Gültig bis ${_dateLabel(feature.validTo!)}',
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(' · ');
  }

  int _severity(DriveWarningKind kind) => switch (kind) {
    DriveWarningKind.closure => 5,
    DriveWarningKind.roadwork => 4,
    DriveWarningKind.restriction => 3,
    DriveWarningKind.incident => 2,
  };

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute Uhr';
  }

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
