import 'sensor_permission_status.dart';

abstract class PermissionRepository {
  SensorPermissionStatus getCurrentPermissionStatus();
}
