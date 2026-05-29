import 'speed_camera_report_confidence.dart';
import 'speed_camera_report_sync_status.dart';
import 'speed_camera_report_type.dart';

enum SpeedCameraReportAppMode {
  liveAr('liveAr'),
  partialLive('partialLive'),
  fallback('fallback');

  const SpeedCameraReportAppMode(this.storageValue);

  final String storageValue;

  static SpeedCameraReportAppMode fromStorageValue(String? value) =>
      switch (value) {
        'liveAr' => liveAr,
        'partialLive' => partialLive,
        _ => fallback,
      };
}

final class SpeedCameraReport {
  const SpeedCameraReport({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.appMode,
    this.expiresAt,
    this.locationAccuracyMeters,
    this.headingDegrees,
    this.speedKmh,
    this.cameraZoomLabel,
    this.confidence = SpeedCameraReportConfidence.low,
    this.source = 'community',
    this.syncStatus = SpeedCameraReportSyncStatus.localOnly,
    this.userId,
    this.moderationStatus = 'active',
    this.verificationCount = 0,
  });

  final String id;
  final SpeedCameraReportType type;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracyMeters;
  final double? headingDegrees;
  final double? speedKmh;
  final String? cameraZoomLabel;
  final SpeedCameraReportAppMode appMode;
  final SpeedCameraReportConfidence confidence;
  final String source;
  final SpeedCameraReportSyncStatus syncStatus;
  final String? userId;
  final String moderationStatus;
  final int verificationCount;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool isActiveAt(DateTime now) =>
      moderationStatus == 'active' &&
      (expiresAt == null || expiresAt!.isAfter(now));

  SpeedCameraReport copyWith({
    DateTime? expiresAt,
    SpeedCameraReportSyncStatus? syncStatus,
    String? userId,
    String? id,
  }) => SpeedCameraReport(
    id: id ?? this.id,
    type: type,
    createdAt: createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    latitude: latitude,
    longitude: longitude,
    locationAccuracyMeters: locationAccuracyMeters,
    headingDegrees: headingDegrees,
    speedKmh: speedKmh,
    cameraZoomLabel: cameraZoomLabel,
    appMode: appMode,
    confidence: confidence,
    source: source,
    syncStatus: syncStatus ?? this.syncStatus,
    userId: userId ?? this.userId,
    moderationStatus: moderationStatus,
    verificationCount: verificationCount,
  );

  Map<String, Object?> toSupabaseInsert(String authenticatedUserId) => {
    'report_type': type.storageValue,
    'user_id': authenticatedUserId,
    'latitude': latitude,
    'longitude': longitude,
    'location_accuracy_meters': locationAccuracyMeters,
    'heading_degrees': headingDegrees,
    'speed_kmh': speedKmh,
    'camera_zoom_label': cameraZoomLabel,
    'app_mode': appMode.storageValue,
    'confidence': confidence.storageValue,
    'source': source,
    'moderation_status': moderationStatus,
  };

  static SpeedCameraReport fromSupabase(Map<String, dynamic> row) {
    final createdAt =
        DateTime.tryParse('${row['created_at']}')?.toUtc() ??
        DateTime.now().toUtc();
    return SpeedCameraReport(
      id: '${row['id']}',
      type: SpeedCameraReportType.fromStorageValue('${row['report_type']}'),
      createdAt: createdAt,
      expiresAt: DateTime.tryParse('${row['expires_at']}')?.toUtc(),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      locationAccuracyMeters: (row['location_accuracy_meters'] as num?)
          ?.toDouble(),
      headingDegrees: (row['heading_degrees'] as num?)?.toDouble(),
      speedKmh: (row['speed_kmh'] as num?)?.toDouble(),
      cameraZoomLabel: row['camera_zoom_label'] as String?,
      appMode: SpeedCameraReportAppMode.fromStorageValue(
        row['app_mode'] as String?,
      ),
      confidence: SpeedCameraReportConfidence.fromStorageValue(
        row['confidence'] as String?,
      ),
      source: row['source'] as String? ?? 'community',
      syncStatus: SpeedCameraReportSyncStatus.synced,
      userId: row['user_id'] as String?,
      moderationStatus: row['moderation_status'] as String? ?? 'active',
      verificationCount: (row['verification_count'] as num?)?.toInt() ?? 0,
    );
  }
}
