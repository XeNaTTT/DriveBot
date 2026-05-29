import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/speed_camera_report.dart';
import '../domain/speed_camera_report_repository.dart';
import '../domain/speed_camera_report_sync_status.dart';

final class SupabaseSpeedCameraReportRepository
    implements SpeedCameraReportRepository {
  const SupabaseSpeedCameraReportRepository(
    this._client, {
    this.timeout = const Duration(seconds: 4),
  });

  final SupabaseClient _client;
  final Duration timeout;

  @override
  Future<SpeedCameraReport> saveLocal(SpeedCameraReport report) async => report;

  @override
  Future<SpeedCameraReport> upload({
    required SpeedCameraReport report,
    required String userId,
  }) async {
    if (!report.hasCoordinates) {
      return report.copyWith(syncStatus: SpeedCameraReportSyncStatus.localOnly);
    }

    final rows = await _client
        .from('speed_camera_reports')
        .insert(report.toSupabaseInsert(userId))
        .select()
        .timeout(timeout);
    final row = rows.first;
    return SpeedCameraReport.fromSupabase(
      row,
    ).copyWith(syncStatus: SpeedCameraReportSyncStatus.synced);
  }

  @override
  Future<List<SpeedCameraReport>> fetchActiveCommunityReports() async {
    final now = DateTime.now().toUtc();
    final rows = await _client
        .from('speed_camera_reports')
        .select()
        .eq('moderation_status', 'active')
        .gt('expires_at', now.toIso8601String())
        .timeout(timeout);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(SpeedCameraReport.fromSupabase)
        .where((report) => report.isActiveAt(now) && report.hasCoordinates)
        .toList(growable: false);
  }

  @override
  List<SpeedCameraReport> getLocalReports() => const [];
}
