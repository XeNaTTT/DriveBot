import 'dart:async';

import '../../hud/domain/hud_warning_item.dart';
import '../../warnings/data/warning_cache.dart';
import '../../warnings/domain/warning_repository.dart';
import '../../warnings/domain/warning_repository_result.dart';
import '../../warnings/domain/warning_request.dart';
import 'autobahn_client.dart';

typedef AutobahnTrafficFetcher =
    Future<List<AutobahnTrafficItem>> Function(String roadId);

class AutobahnWarningRepository implements WarningRepository {
  AutobahnWarningRepository({
    required this.fetchTrafficItems,
    this.defaultRoadId = 'A3',
    this.cache,
    this.timeout = const Duration(seconds: 4),
  });

  factory AutobahnWarningRepository.live({
    String defaultRoadId = 'A3',
    WarningCache? cache,
    Duration timeout = const Duration(seconds: 4),
  }) {
    final client = AutobahnClient();
    return AutobahnWarningRepository(
      fetchTrafficItems: client.fetchTrafficItems,
      defaultRoadId: defaultRoadId,
      cache: cache,
      timeout: timeout,
    );
  }

  final AutobahnTrafficFetcher fetchTrafficItems;
  final String defaultRoadId;
  final WarningCache? cache;
  final Duration timeout;

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    final cacheKey = '${request.cacheKey}:$defaultRoadId';
    final cached = cache?.read(cacheKey);
    if (cached != null && cached.hasWarnings) {
      return WarningRepositoryResult.cache(cached.warnings);
    }

    try {
      final items = await fetchTrafficItems(defaultRoadId).timeout(timeout);
      if (items.isEmpty) return const WarningRepositoryResult.empty();

      final warnings = items
          .take(4)
          .map((item) => _mapItem(item, request))
          .toList(growable: false);
      final result = WarningRepositoryResult.live(warnings);
      cache?.write(cacheKey, result);
      return result;
    } on TimeoutException {
      return const WarningRepositoryResult.failure('autobahn-api-timeout');
    } catch (_) {
      return const WarningRepositoryResult.failure('autobahn-api-error');
    }
  }

  HudWarningItem _mapItem(AutobahnTrafficItem item, WarningRequest request) {
    return HudWarningItem(
      type: item.isRoadwork ? WarningType.roadwork : WarningType.speedLimit,
      title: item.title,
      detail: item.detail,
      distanceMeters: item.isRoadwork ? 1200 : 900,
      bearingDegrees: request.headingDegrees,
      severity: item.isRoadwork ? 3 : 4,
    );
  }
}
