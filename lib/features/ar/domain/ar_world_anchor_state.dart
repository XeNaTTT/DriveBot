import 'ar_runtime_state.dart';

final class ArWorldAnchorState {
  const ArWorldAnchorState({
    required this.id,
    required this.trackingQuality,
    required this.isAnchored,
    this.distanceMeters,
    this.message,
  });

  final String id;
  final ArTrackingQuality trackingQuality;
  final bool isAnchored;
  final double? distanceMeters;
  final String? message;

  static ArWorldAnchorState fromNativeMap(Map<Object?, Object?> map) {
    final quality = switch (map['trackingQuality']) {
      'stable' => ArTrackingQuality.stable,
      'limited' => ArTrackingQuality.limited,
      'unavailable' => ArTrackingQuality.unavailable,
      _ => ArTrackingQuality.unknown,
    };
    return ArWorldAnchorState(
      id: (map['id'] as String?) ?? '',
      trackingQuality: quality,
      isAnchored: map['isAnchored'] == true,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
      message: map['message'] as String?,
    );
  }
}
