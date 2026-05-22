import 'data_source_status.dart';

abstract class DataSourceRegistry {
  List<DataSourceStatus> getRegisteredSources();
}
