import 'ar_runtime_state.dart';

enum ArProjectionSource { native, fallback }

final class ArWorldAnchorState {
  const ArWorldAnchorState({
    required this.id,
    required this.trackingQuality,
    required this.isAnchored,
    this.distanceMeters,
    this.message,
    this.normalizedX,
    this.top,
    this.isVisible = false,
    this.hiddenReason,
    this.trackingConfidence = 0,
    this.projectionSource = ArProjectionSource.fallback,
    this.lastRecalibrationAgeSeconds,
  });

  final String id;
  final ArTrackingQuality trackingQuality;
  final bool isAnchored;
  final double? distanceMeters;
  final String? message;
  final double? normalizedX;
  final double? top;
  final bool isVisible;
  final String? hiddenReason;
  final double trackingConfidence;
  final ArProjectionSource projectionSource;
  final double? lastRecalibrationAgeSeconds;

  bool get hasNativeScreenPosition =>
      projectionSource == ArProjectionSource.native &&
      isVisible &&
      normalizedX != null &&
      top != null;

  static ArWorldAnchorState fromNativeMap(Map<Object?, Object?> map) {
    final quality = switch (map['trackingQuality']) {
      'stable' => ArTrackingQuality.stable,
      'limited' => ArTrackingQuality.limited,
      'unavailable' => ArTrackingQuality.unavailable,
      _ => ArTrackingQuality.unknown,
    };
    final projectionSource = switch (map['projectionSource']) {
      'native' => ArProjectionSource.native,
      _ => ArProjectionSource.fallback,
    };
    return ArWorldAnchorState(
      id: (map['id'] as String?) ?? '',
      trackingQuality: quality,
      isAnchored: map['isAnchored'] == true,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
      message: map['message'] as String?,
      normalizedX: (map['normalizedX'] as num?)?.toDouble(),
      top: (map['top'] as num?)?.toDouble(),
      isVisible: map['isVisible'] == true,
      hiddenReason: map['hiddenReason'] as String?,
      trackingConfidence: (map['trackingConfidence'] as num?)?.toDouble() ?? 0,
      projectionSource: projectionSource,
      lastRecalibrationAgeSeconds: (map['lastRecalibrationAgeSeconds'] as num?)
          ?.toDouble(),
    );
  }
}
