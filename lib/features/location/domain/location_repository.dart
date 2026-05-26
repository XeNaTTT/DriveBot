import 'package:flutter/foundation.dart';

import 'location_status.dart';

abstract class LocationRepository {
  ValueListenable<LocationStatus> get locationStatusListenable;
}
