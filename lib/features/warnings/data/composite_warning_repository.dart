import '../../hud/domain/hud_repository.dart';
import '../../hud/domain/hud_warning_item.dart';
import '../domain/warning_repository.dart';
import '../domain/warning_repository_result.dart';
import '../domain/warning_request.dart';
import 'mock_warning_repository.dart';

class CompositeWarningRepository implements WarningRepository, HudRepository {
  CompositeWarningRepository({
    required WarningRepository primary,
    MockWarningRepository? fallback,
  })  : _primary = primary,
        _fallback = fallback ?? MockWarningRepository() {
    _latestWarnings = _fallback.getNearbyWarnings();
  }

  final WarningRepository _primary;
  final MockWarningRepository _fallback;
  late List<HudWarningItem> _latestWarnings;

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    final primaryResult = await _primary.getWarnings(request);
    if (primaryResult.hasWarnings) {
      _latestWarnings = primaryResult.warnings;
      return primaryResult;
    }

    final fallbackResult = await _fallback.getWarnings(request);
    _latestWarnings = fallbackResult.warnings;
    return fallbackResult;
  }

  @override
  List<HudWarningItem> getNearbyWarnings() => _latestWarnings;
}
