import '../../hud/domain/hud_warning_item.dart';
import '../domain/warning_repository.dart';
import '../domain/warning_repository_result.dart';
import '../domain/warning_request.dart';

class MergedWarningRepository implements WarningRepository {
  const MergedWarningRepository(this.repositories);

  final List<WarningRepository> repositories;

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    final warnings = <HudWarningItem>[];
    WarningRepositoryResult? fallbackResult;

    for (final repository in repositories) {
      final result = await repository.getWarnings(request);
      if (result.hasWarnings) {
        warnings.addAll(result.warnings);
      } else {
        fallbackResult ??= result;
      }
    }

    if (warnings.isEmpty) {
      return fallbackResult ?? const WarningRepositoryResult.empty();
    }

    return WarningRepositoryResult.live(warnings);
  }
}
