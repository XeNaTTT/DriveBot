import '../../hud/data/mock_hud_repository.dart';
import '../../hud/domain/hud_repository.dart';
import '../../hud/domain/hud_warning_item.dart';
import '../domain/warning_repository.dart';
import '../domain/warning_repository_result.dart';
import '../domain/warning_request.dart';

class MockWarningRepository implements WarningRepository, HudRepository {
  MockWarningRepository({List<HudWarningItem>? warnings})
      : _warnings = warnings ?? MockHudRepository().getNearbyWarnings();

  final List<HudWarningItem> _warnings;

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    return WarningRepositoryResult.fallback(_warnings);
  }

  @override
  List<HudWarningItem> getNearbyWarnings() => _warnings;
}
