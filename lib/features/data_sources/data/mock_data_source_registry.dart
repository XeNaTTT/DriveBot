import '../domain/data_source_registry.dart';
import '../domain/data_source_status.dart';

class MockDataSourceRegistry implements DataSourceRegistry {
  @override
  List<DataSourceStatus> getRegisteredSources() {
    return const [
      DataSourceStatus(name: 'OpenStreetMap/Overpass', enabled: false),
      DataSourceStatus(name: 'Open-Meteo/Bright Sky', enabled: false),
      DataSourceStatus(name: 'Autobahn API', enabled: false),
      DataSourceStatus(name: 'Tankerkönig', enabled: false),
      DataSourceStatus(name: 'OpenRouteService', enabled: false),
    ];
  }
}
