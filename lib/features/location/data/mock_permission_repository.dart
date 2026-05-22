import '../domain/permission_repository.dart';
import '../domain/sensor_permission_status.dart';

class MockPermissionRepository implements PermissionRepository {
  const MockPermissionRepository({
    this.permissionStatus = const SensorPermissionStatus(
      camera: SensorPermissionState.denied,
      location: SensorPermissionState.denied,
      motion: SensorPermissionState.denied,
    ),
  });

  final SensorPermissionStatus permissionStatus;

  @override
  SensorPermissionStatus getCurrentPermissionStatus() => permissionStatus;
}
