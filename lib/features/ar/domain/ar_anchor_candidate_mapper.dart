import '../../reports/domain/speed_camera_report.dart';
import 'ar_anchor_model.dart';
import 'ar_marker_model.dart';

final class ArAnchorCandidateMapper {
  const ArAnchorCandidateMapper();

  List<ArAnchorModel> fromMarkers(List<ArMarkerModel> markers) => markers
      .map(
        (marker) => ArAnchorModel.fromWarning(
          marker.warning,
          relativeBearing: marker.relativeBearing,
        ),
      )
      .toList(growable: false);

  List<ArAnchorModel> fromSpeedCameraReports(
    List<SpeedCameraReport> reports, {
    required DateTime now,
  }) => reports
      .where((report) => report.isActiveAt(now) && report.hasCoordinates)
      .map(ArAnchorModel.fromSpeedCameraReport)
      .toList(growable: false);
}
