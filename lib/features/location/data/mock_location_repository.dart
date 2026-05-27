import 'package:flutter/foundation.dart';

import '../domain/location_repository.dart';
import '../domain/location_status.dart';

class MockLocationRepository implements LocationRepository {
  MockLocationRepository()
      : _status = ValueNotifier(
          const LocationStatus(
            speedKph: 84,
            headingDegrees: 58,
            gpsFixStatus: GpsFixStatus.strong,
            isMock: true,
            isSpeedEstimatedFromGps: false,
          ),
        );

  final ValueNotifier<LocationStatus> _status;

  @override
  ValueListenable<LocationStatus> get locationStatusListenable => _status;
}
