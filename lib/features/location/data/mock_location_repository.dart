import '../domain/location_repository.dart';
import '../domain/location_status.dart';

class MockLocationRepository implements LocationRepository {
  @override
  LocationStatus getCurrentStatus() {
    return const LocationStatus(
      speedKph: 84,
      headingDegrees: 58,
      gpsFixStatus: GpsFixStatus.strong,
      isMock: true,
      isSpeedEstimatedFromGps: false,
    );
  }
}
