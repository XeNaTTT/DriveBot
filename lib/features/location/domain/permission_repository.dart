import 'package:flutter/foundation.dart';

import 'sensor_permission_status.dart';

abstract class PermissionRepository {
  ValueListenable<SensorPermissionStatus> get permissionStatusListenable;
}

/// A permission source whose camera and motion sensors can be started lazily.
abstract class VisualSensorPermissionRepository
    implements PermissionRepository {
  Future<void> enableVisualSensors();
}
