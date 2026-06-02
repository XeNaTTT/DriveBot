import '../../hud/domain/hud_repository.dart';
import '../../hud/domain/hud_warning_item.dart';
import '../domain/warning_repository.dart';
import '../domain/warning_repository_result.dart';
import '../domain/warning_request.dart';
import 'mock_warning_repository.dart';

class CompositeWarningRepository
    implements WarningRepository, WarningDataSourceStatus, HudRepository {
  CompositeWarningRepository({
    required this.primary,
    MockWarningRepository? fallback,
  }) : _fallback = fallback ?? MockWarningRepository() {
    _latestWarnings = _fallback.getNearbyWarnings();
    _latestResult = WarningRepositoryResult.fallback(_latestWarnings);
  }

  final WarningRepository primary;
  final MockWarningRepository _fallback;
  late WarningRepositoryResult _latestResult;
  late List<HudWarningItem> _latestWarnings;

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    final primaryResult = await primary.getWarnings(request);
    if (primaryResult.hasWarnings) {
      _applyResultIfMeaningful(primaryResult);
      return primaryResult;
    }

    final fallbackResult = await _fallback.getWarnings(request);
    _applyResultIfMeaningful(fallbackResult);
    return fallbackResult;
  }

  void _applyResultIfMeaningful(WarningRepositoryResult result) {
    if (_hasMeaningfulWarningChange(_latestWarnings, result.warnings) ||
        _latestResult.source != result.source) {
      _latestWarnings = List.unmodifiable(result.warnings);
      _latestResult = result;
    }
  }

  bool _hasMeaningfulWarningChange(
    List<HudWarningItem> previous,
    List<HudWarningItem> next,
  ) {
    if (previous.length != next.length) return true;
    final previousIds = previous.map((warning) => warning.stableId).toList()
      ..sort();
    final nextIds = next.map((warning) => warning.stableId).toList()..sort();
    for (var i = 0; i < previousIds.length; i++) {
      if (previousIds[i] != nextIds[i]) return true;
    }
    return false;
  }

  @override
  List<HudWarningItem> getNearbyWarnings() => _latestWarnings;

  @override
  WarningDataSource get dataSource => _latestResult.source;

  @override
  String get dataSourceLabel => dataSource.userFacingGermanLabel;

  @override
  String get debugDataSourceLabel => dataSource.debugGermanLabel;
}
