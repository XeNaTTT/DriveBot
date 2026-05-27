import '../../hud/domain/hud_repository.dart';
import '../../hud/domain/hud_warning_item.dart';
import '../domain/warning_repository.dart';
import '../domain/warning_repository_result.dart';
import '../domain/warning_request.dart';
import 'mock_warning_repository.dart';

class CompositeWarningRepository
    implements WarningRepository, WarningDataSourceStatus, HudRepository {
  CompositeWarningRepository({
    required WarningRepository primary,
    MockWarningRepository? fallback,
  })  : _primary = primary,
        _fallback = fallback ?? MockWarningRepository() {
    _latestWarnings = _fallback.getNearbyWarnings();
  }

  final WarningRepository _primary;
  final MockWarningRepository _fallback;
  WarningRepositoryResult _latestResult = const WarningRepositoryResult.empty();
  late List<HudWarningItem> _latestWarnings;

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    final primaryResult = await _primary.getWarnings(request);
    if (primaryResult.hasWarnings) {
      _latestWarnings = primaryResult.warnings;
      _latestResult = primaryResult;
      return primaryResult;
    }

    final fallbackResult = await _fallback.getWarnings(request);
    _latestWarnings = fallbackResult.warnings;
    _latestResult = fallbackResult;
    return fallbackResult;
  }

  @override
  List<HudWarningItem> getNearbyWarnings() => _latestWarnings;

  @override
  String get dataSourceLabel {
    return switch (_latestResult.source) {
      WarningDataSource.liveApi || WarningDataSource.cache => 'Live data',
      _ => 'Fallback data',
    };
  }
}
