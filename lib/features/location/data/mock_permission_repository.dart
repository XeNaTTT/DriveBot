import 'package:flutter/foundation.dart';

import '../domain/permission_repository.dart';
import '../domain/sensor_permission_status.dart';

class MockPermissionRepository implements PermissionRepository {
  MockPermissionRepository({
    this.permissionStatus = const SensorPermissionStatus(
      camera: SensorPermissionState.denied,
      location: SensorPermissionState.denied,
      motion: SensorPermissionState.denied,
    ),
  }) : _status = ValueNotifier(permissionStatus);

  final SensorPermissionStatus permissionStatus;
  final ValueNotifier<SensorPermissionStatus> _status;

  @override
  ValueListenable<SensorPermissionStatus> get permissionStatusListenable =>
      _status;
}
