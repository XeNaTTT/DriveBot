import '../domain/speed_camera_report.dart';
import '../domain/speed_camera_report_repository.dart';
import '../domain/speed_camera_report_sync_status.dart';
import 'local_speed_camera_report_repository.dart';

final class CompositeSpeedCameraReportRepository
    implements SpeedCameraReportRepository {
  CompositeSpeedCameraReportRepository(
    this._localRepository, {
    this.remoteRepository,
  });

  final LocalSpeedCameraReportRepository _localRepository;
  final SpeedCameraReportRepository? remoteRepository;

  bool get hasRemoteSync => remoteRepository != null;

  @override
  Future<SpeedCameraReport> saveLocal(SpeedCameraReport report) =>
      _localRepository.saveLocal(report);

  @override
  Future<SpeedCameraReport> upload({
    required SpeedCameraReport report,
    required String userId,
  }) async {
    final remote = remoteRepository;
    if (remote == null) {
      return _localRepository.saveLocal(
        report.copyWith(syncStatus: SpeedCameraReportSyncStatus.localOnly),
      );
    }

    try {
      final synced = await remote.upload(report: report, userId: userId);
      await _localRepository.saveLocal(synced);
      return synced;
    } on Object {
      final failed = report.copyWith(
        userId: userId,
        syncStatus: SpeedCameraReportSyncStatus.failed,
      );
      await _localRepository.saveLocal(failed);
      return failed;
    }
  }

  @override
  Future<List<SpeedCameraReport>> fetchActiveCommunityReports() async {
    final now = DateTime.now().toUtc();
    final local = _localRepository.getLocalReports();
    final remote = remoteRepository;
    final reports = <SpeedCameraReport>[];
    if (remote != null) {
      try {
        reports.addAll(await remote.fetchActiveCommunityReports());
      } on Object {
        // Remote community reports must never block HUD rendering.
      }
    }
    reports.addAll(local);
    return reports
        .where((report) => report.isActiveAt(now) && report.hasCoordinates)
        .toList(growable: false);
  }

  @override
  List<SpeedCameraReport> getLocalReports() =>
      _localRepository.getLocalReports();
}
