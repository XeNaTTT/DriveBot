import 'location_status.dart';

abstract class LocationRepository {
  LocationStatus getCurrentStatus();
}
