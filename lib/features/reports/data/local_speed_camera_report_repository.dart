import '../domain/speed_camera_report.dart';
import '../domain/speed_camera_report_repository.dart';
import '../domain/speed_camera_report_sync_status.dart';

final class LocalSpeedCameraReportRepository
    implements SpeedCameraReportRepository {
  LocalSpeedCameraReportRepository({List<SpeedCameraReport>? initialReports})
    : _reports = [...?initialReports];

  final List<SpeedCameraReport> _reports;

  @override
  Future<SpeedCameraReport> saveLocal(SpeedCameraReport report) async {
    final local = report.copyWith(
      syncStatus: SpeedCameraReportSyncStatus.localOnly,
    );
    _upsert(local);
    return local;
  }

  @override
  Future<SpeedCameraReport> upload({
    required SpeedCameraReport report,
    required String userId,
  }) async {
    final local = report.copyWith(
      userId: userId,
      syncStatus: SpeedCameraReportSyncStatus.localOnly,
    );
    _upsert(local);
    return local;
  }

  @override
  Future<List<SpeedCameraReport>> fetchActiveCommunityReports() async {
    final now = DateTime.now().toUtc();
    return _reports
        .where((report) => report.isActiveAt(now) && report.hasCoordinates)
        .toList(growable: false);
  }

  @override
  List<SpeedCameraReport> getLocalReports() => List.unmodifiable(_reports);

  void _upsert(SpeedCameraReport report) {
    final index = _reports.indexWhere((entry) => entry.id == report.id);
    if (index == -1) {
      _reports.add(report);
    } else {
      _reports[index] = report;
    }
  }
}
