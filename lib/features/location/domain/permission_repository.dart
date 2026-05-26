import 'package:flutter/foundation.dart';

import 'sensor_permission_status.dart';

abstract class PermissionRepository {
  ValueListenable<SensorPermissionStatus> get permissionStatusListenable;
}
