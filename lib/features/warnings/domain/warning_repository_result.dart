import '../../hud/domain/hud_warning_item.dart';

enum WarningDataSource { liveApi, fallback, cache, empty, failure }

class WarningRepositoryResult {
  const WarningRepositoryResult({
    required this.warnings,
    required this.source,
    this.failureReason,
  });

  const WarningRepositoryResult.live(List<HudWarningItem> warnings)
      : this(warnings: warnings, source: WarningDataSource.liveApi);

  const WarningRepositoryResult.fallback(List<HudWarningItem> warnings)
      : this(warnings: warnings, source: WarningDataSource.fallback);

  const WarningRepositoryResult.cache(List<HudWarningItem> warnings)
      : this(warnings: warnings, source: WarningDataSource.cache);

  const WarningRepositoryResult.empty()
      : this(warnings: const [], source: WarningDataSource.empty);

  const WarningRepositoryResult.failure(String reason)
      : this(
          warnings: const [],
          source: WarningDataSource.failure,
          failureReason: reason,
        );

  final List<HudWarningItem> warnings;
  final WarningDataSource source;
  final String? failureReason;

  bool get hasWarnings => warnings.isNotEmpty;
  bool get isLive => source == WarningDataSource.liveApi;
}
