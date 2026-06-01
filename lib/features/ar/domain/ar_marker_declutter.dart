import '../../hud/domain/hud_warning_item.dart';
import 'ar_marker_model.dart';

final class ArMarkerDeclutterResult {
  const ArMarkerDeclutterResult({
    required this.visibleMarkers,
    required this.hiddenByOverlap,
  });

  final List<ArMarkerModel> visibleMarkers;
  final int hiddenByOverlap;
}

final class ArMarkerDeclutter {
  const ArMarkerDeclutter({
    this.maxVisibleMarkers = 5,
    this.maxSpeedCameraMarkers = 3,
    this.maxTrafficHintMarkers = 2,
    this.minHorizontalSpacing = 0.16,
    this.minVerticalSpacing = 0.09,
    this.verticalStackStep = 0.055,
  });

  final int maxVisibleMarkers;
  final int maxSpeedCameraMarkers;
  final int maxTrafficHintMarkers;
  final double minHorizontalSpacing;
  final double minVerticalSpacing;
  final double verticalStackStep;

  ArMarkerDeclutterResult apply({
    required List<ArMarkerModel> markers,
    String? selectedInfoObjectId,
  }) {
    if (markers.isEmpty) {
      return const ArMarkerDeclutterResult(
        visibleMarkers: [],
        hiddenByOverlap: 0,
      );
    }

    final ranked = [...markers]
      ..sort(
        (a, b) => _priorityScore(
          b,
          selectedInfoObjectId,
        ).compareTo(_priorityScore(a, selectedInfoObjectId)),
      );
    final visible = <ArMarkerModel>[];
    var hidden = 0;
    var speedCameras = 0;
    var trafficHints = 0;

    for (final marker in ranked) {
      final type = marker.infoObject.type;
      final isSelected = marker.infoObject.id == selectedInfoObjectId;
      if (!isSelected && visible.length >= maxVisibleMarkers) {
        hidden++;
        continue;
      }
      if (!isSelected && type == WarningType.speedCamera) {
        if (speedCameras >= maxSpeedCameraMarkers) {
          hidden++;
          continue;
        }
      }
      if (!isSelected && _isTrafficHint(type)) {
        if (trafficHints >= maxTrafficHintMarkers) {
          hidden++;
          continue;
        }
      }

      final resolved = _resolveOverlap(marker, visible, isSelected: isSelected);
      if (resolved == null) {
        hidden++;
        continue;
      }
      visible.add(resolved);
      if (type == WarningType.speedCamera) speedCameras++;
      if (_isTrafficHint(type)) trafficHints++;
    }

    visible.sort(
      (a, b) => _priorityScore(
        a,
        selectedInfoObjectId,
      ).compareTo(_priorityScore(b, selectedInfoObjectId)),
    );

    return ArMarkerDeclutterResult(
      visibleMarkers: visible,
      hiddenByOverlap: hidden,
    );
  }

  ArMarkerModel? _resolveOverlap(
    ArMarkerModel marker,
    List<ArMarkerModel> visible, {
    required bool isSelected,
  }) {
    final candidates = <ArMarkerModel>[
      marker,
      for (final offset in const [0.10, -0.10, 0.20, -0.16, 0.28])
        marker.copyWith(top: (marker.top + offset).clamp(0.20, 0.68)),
    ];
    for (final candidate in candidates) {
      if (!_overlapsAny(candidate, visible)) return candidate;
    }
    return isSelected ? candidates.last : null;
  }

  bool _overlapsAny(ArMarkerModel marker, List<ArMarkerModel> visible) =>
      visible.any(
        (other) =>
            (marker.normalizedX - other.normalizedX).abs() <
                minHorizontalSpacing &&
            (marker.top - other.top).abs() < minVerticalSpacing,
      );

  int _priorityScore(ArMarkerModel marker, String? selectedInfoObjectId) {
    final object = marker.infoObject;
    final warning = object.warning;
    final distance = object.distanceMeters ?? warning.distanceMeters.toDouble();
    final selected = object.id == selectedInfoObjectId ? 10000 : 0;
    final typeScore = switch (object.type) {
      WarningType.speedCamera => _isMobileSpeedCamera(marker) ? 6000 : 5600,
      WarningType.chargingStation => 4800,
      WarningType.weather => 3800,
      WarningType.speedLimit => 3400,
      WarningType.roadwork => 3000,
      WarningType.notice => 1800,
    };
    final severityScore = warning.severity * 220;
    final distanceScore = (3000 - distance.clamp(0, 3000)).round();
    return selected + typeScore + severityScore + distanceScore;
  }

  bool _isMobileSpeedCamera(ArMarkerModel marker) {
    final text =
        '${marker.infoObject.title} ${marker.infoObject.subtitle} ${marker.infoObject.typeLabel}';
    return text.toLowerCase().contains('mobil');
  }

  bool _isTrafficHint(WarningType type) => switch (type) {
    WarningType.speedLimit ||
    WarningType.roadwork ||
    WarningType.notice => true,
    WarningType.speedCamera ||
    WarningType.weather ||
    WarningType.chargingStation => false,
  };
}
