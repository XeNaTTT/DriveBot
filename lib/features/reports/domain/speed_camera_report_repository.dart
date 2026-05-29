import 'speed_camera_report.dart';

abstract interface class SpeedCameraReportRepository {
  Future<SpeedCameraReport> saveLocal(SpeedCameraReport report);

  Future<SpeedCameraReport> upload({
    required SpeedCameraReport report,
    required String userId,
  });

  Future<List<SpeedCameraReport>> fetchActiveCommunityReports();

  List<SpeedCameraReport> getLocalReports();
}
