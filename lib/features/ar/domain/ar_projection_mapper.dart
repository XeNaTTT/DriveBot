import '../../hud/domain/hud_warning_item.dart';
import 'ar_marker_model.dart';

class ArProjectionMapper {
  const ArProjectionMapper({
    this.horizontalFovDegrees = 60,
    this.minTop = 0.22,
    this.maxTop = 0.62,
  });

  final double horizontalFovDegrees;
  final double minTop;
  final double maxTop;

  List<ArMarkerModel> project({
    required List<HudWarningItem> warnings,
    required int userHeadingDegrees,
  }) {
    final halfFov = horizontalFovDegrees / 2;
    return warnings
        .where((w) => w.bearingDegrees >= 0)
        .map((warning) {
          final relative = _normalizeAngle(
            warning.bearingDegrees.toDouble() - userHeadingDegrees,
          );
          if (relative.abs() > halfFov) return null;
          final normalizedX = ((relative / halfFov) + 1) / 2;
          final clampedDistance = warning.distanceMeters.clamp(75, 3000);
          final depth = 1 - ((clampedDistance - 75) / (3000 - 75));
          final top = minTop + ((maxTop - minTop) * depth);
          return ArMarkerModel(
            warning: warning,
            relativeBearing: relative,
            normalizedX: normalizedX.clamp(0, 1),
            top: top.clamp(minTop, maxTop),
          );
        })
        .whereType<ArMarkerModel>()
        .toList(growable: false);
  }

  double _normalizeAngle(double degrees) {
    var normalized = degrees % 360;
    if (normalized > 180) normalized -= 360;
    if (normalized < -180) normalized += 360;
    return normalized;
  }
}
