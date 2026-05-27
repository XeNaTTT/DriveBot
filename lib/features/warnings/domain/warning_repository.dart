import 'warning_repository_result.dart';
import 'warning_request.dart';

abstract class WarningRepository {
  Future<WarningRepositoryResult> getWarnings(WarningRequest request);
}

abstract class WarningDataSourceStatus {
  String get dataSourceLabel;
}
