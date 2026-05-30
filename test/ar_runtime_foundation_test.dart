import 'package:driveassistant_ar/features/ar/data/ar_runtime_service.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_anchor_candidate_mapper.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_anchor_model.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_runtime_state.dart';
import 'package:driveassistant_ar/features/ar/domain/ar_projection_mapper.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report_confidence.dart';
import 'package:driveassistant_ar/features/reports/domain/speed_camera_report_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsupported AR runtime uses German camera fallback label', () async {
    final service = const FallbackArRuntimeService();

    expect(await service.isSupported(), isFalse);
    expect((await service.getState()).germanStatusLabel, 'Kamera-Fallback');
  });

  test('supported AR runtime exposes German active and tracking labels', () {
    expect(
      const ArRuntimeState.available(isRunning: true).germanStatusLabel,
      'AR aktiv',
    );
    expect(
      const ArRuntimeState.available()
          .copyWith(trackingQuality: ArTrackingQuality.limited)
          .germanStatusLabel,
      'Tracking eingeschränkt',
    );
  });

  test('warning markers map to AR anchor candidates', () {
    final markers = const ArProjectionMapper().project(
      warnings: const [
        HudWarningItem(
          type: WarningType.speedCamera,
          title: 'Blitzer A3',
          detail: 'Feste Kamera',
          distanceMeters: 250,
          bearingDegrees: 10,
          severity: 4,
        ),
      ],
      userHeadingDegrees: 0,
    );

    final anchors = const ArAnchorCandidateMapper().fromMarkers(markers);

    expect(anchors.single.type, ArAnchorType.speedCamera);
    expect(anchors.single.label, 'Blitzer A3');
  });

  test('active community speed camera reports map to AR anchors', () {
    final now = DateTime.utc(2026, 5, 29);
    final anchors = const ArAnchorCandidateMapper().fromSpeedCameraReports([
      SpeedCameraReport(
        id: 'report-1',
        type: SpeedCameraReportType.fixed,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 2)),
        latitude: 50.1,
        longitude: 8.6,
        appMode: SpeedCameraReportAppMode.liveAr,
        confidence: SpeedCameraReportConfidence.high,
      ),
    ], now: now);

    expect(anchors.single.type, ArAnchorType.speedCamera);
    expect(anchors.single.confidence, greaterThan(0.8));
  });

  test('charging station anchor type exists', () {
    const anchor = ArAnchorModel(
      id: 'charge-1',
      type: ArAnchorType.chargingStation,
      label: 'Ladestation',
      severity: ArAnchorSeverity.low,
      source: 'test',
    );

    expect(anchor.type, ArAnchorType.chargingStation);
  });
}
