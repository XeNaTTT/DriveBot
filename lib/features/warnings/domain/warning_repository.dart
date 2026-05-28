import 'warning_repository_result.dart';
import 'warning_request.dart';

abstract class WarningRepository {
  Future<WarningRepositoryResult> getWarnings(WarningRequest request);
}

abstract class WarningDataSourceStatus {
  WarningDataSource get dataSource;

  String get dataSourceLabel => dataSource.userFacingGermanLabel;

  String get debugDataSourceLabel => dataSource.debugGermanLabel;
}
