import '../../hud/domain/hud_warning_item.dart';
import 'ar_marker_model.dart';

final class ArMarkerDeclutterResult {
  const ArMarkerDeclutterResult({
    required this.visibleMarkers,
    required this.hiddenByOverlap,
    this.state = const ArMarkerDeclutterState(),
  });

  final List<ArMarkerModel> visibleMarkers;
  final int hiddenByOverlap;
  final ArMarkerDeclutterState state;
}

final class ArMarkerDeclutterState {
  const ArMarkerDeclutterState({
    this.markerStates = const {},
    this.hiddenByOverlap = 0,
    this.visibleIds = const {},
    this.hiddenIds = const {},
    this.clusterSignature = '',
  });

  final Map<String, ArMarkerVisibilityState> markerStates;
  final int hiddenByOverlap;
  final Set<String> visibleIds;
  final Set<String> hiddenIds;
  final String clusterSignature;
}

final class ArMarkerVisibilityState {
  const ArMarkerVisibilityState({
    required this.isVisible,
    required this.changedAt,
  });

  final bool isVisible;
  final DateTime changedAt;
}

final class ArMarkerDeclutter {
  const ArMarkerDeclutter({
    this.maxVisibleMarkers = 6,
    this.maxSpeedCameraMarkers = 3,
    this.maxTrafficHintMarkers = 2,
    this.minHorizontalSpacing = 0.12,
    this.minVerticalSpacing = 0.09,
    this.verticalStackStep = 0.055,
    this.visibleHysteresisDuration = const Duration(milliseconds: 1500),
    this.hiddenHysteresisDuration = const Duration(milliseconds: 1000),
  });

  final int maxVisibleMarkers;
  final int maxSpeedCameraMarkers;
  final int maxTrafficHintMarkers;
  final double minHorizontalSpacing;
  final double minVerticalSpacing;
  final double verticalStackStep;
  final Duration visibleHysteresisDuration;
  final Duration hiddenHysteresisDuration;

  ArMarkerDeclutterResult apply({
    required List<ArMarkerModel> markers,
    String? selectedInfoObjectId,
    ArMarkerDeclutterState previousState = const ArMarkerDeclutterState(),
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    if (markers.isEmpty) {
      return const ArMarkerDeclutterResult(
        visibleMarkers: [],
        hiddenByOverlap: 0,
      );
    }

    final ranked = [...markers]
      ..sort((a, b) => compareDeterministic(a, b, selectedInfoObjectId));
    final selected = _selectedMarker(ranked, selectedInfoObjectId);
    final selectedId = selected?.infoObject.id;
    final visibleById = <String, ArMarkerModel>{};
    final hiddenIds = <String>{};
    var speedCameras = 0;
    var trafficHints = 0;

    for (final marker in ranked) {
      final type = marker.infoObject.type;
      final id = marker.infoObject.id;
      final isSelected = id == selectedId;
      if (!isSelected && visibleById.length >= maxVisibleMarkers) {
        hiddenIds.add(id);
        continue;
      }
      if (!isSelected && type == WarningType.speedCamera) {
        if (speedCameras >= maxSpeedCameraMarkers) {
          hiddenIds.add(id);
          continue;
        }
      }
      if (!isSelected && _isTrafficHint(type)) {
        if (trafficHints >= maxTrafficHintMarkers) {
          hiddenIds.add(id);
          continue;
        }
      }

      final resolved = _resolveOverlap(
        marker,
        visibleById.values.toList(growable: false),
        isSelected: isSelected,
      );
      if (resolved == null) {
        hiddenIds.add(id);
        continue;
      }
      visibleById[id] = resolved;
      if (type == WarningType.speedCamera) speedCameras++;
      if (_isTrafficHint(type)) trafficHints++;
    }

    _applyVisibilityHysteresis(
      ranked: ranked,
      selectedId: selectedId,
      visibleById: visibleById,
      hiddenIds: hiddenIds,
      previousState: previousState,
      now: effectiveNow,
    );

    final visible = visibleById.values.toList(growable: false)
      ..sort(_compareForStablePaint);
    final visibleIds = visibleById.keys.toSet();
    final stableHiddenCount = _stableHiddenCount(
      markers: ranked,
      hiddenIds: hiddenIds,
      previousState: previousState,
    );
    final nextStates = _nextStates(
      markers: ranked,
      visibleIds: visibleIds,
      previousState: previousState,
      now: effectiveNow,
    );

    return ArMarkerDeclutterResult(
      visibleMarkers: visible,
      hiddenByOverlap: stableHiddenCount,
      state: ArMarkerDeclutterState(
        markerStates: nextStates,
        hiddenByOverlap: stableHiddenCount,
        visibleIds: visibleIds,
        hiddenIds: hiddenIds,
        clusterSignature: _clusterSignature(ranked),
      ),
    );
  }

  void _applyVisibilityHysteresis({
    required List<ArMarkerModel> ranked,
    required String? selectedId,
    required Map<String, ArMarkerModel> visibleById,
    required Set<String> hiddenIds,
    required ArMarkerDeclutterState previousState,
    required DateTime now,
  }) {
    final markerById = {
      for (final marker in ranked) marker.infoObject.id: marker,
    };
    if (selectedId != null) {
      final selected = markerById[selectedId];
      if (selected != null && !visibleById.containsKey(selectedId)) {
        visibleById[selectedId] =
            _resolveOverlap(
              selected,
              visibleById.values.toList(growable: false),
              isSelected: true,
            ) ??
            selected;
        hiddenIds.remove(selectedId);
      }
    }

    for (final id in previousState.visibleIds) {
      if (visibleById.containsKey(id)) continue;
      final state = previousState.markerStates[id];
      final marker = markerById[id];
      if (state == null || marker == null) continue;
      if (now.difference(state.changedAt) < visibleHysteresisDuration) {
        visibleById[id] =
            _resolveOverlap(
              marker,
              visibleById.values.toList(growable: false),
              isSelected: id == selectedId,
            ) ??
            marker;
        hiddenIds.remove(id);
      }
    }

    for (final id in previousState.hiddenIds) {
      if (!visibleById.containsKey(id) || id == selectedId) continue;
      final state = previousState.markerStates[id];
      if (state == null) continue;
      if (now.difference(state.changedAt) < hiddenHysteresisDuration) {
        visibleById.remove(id);
        hiddenIds.add(id);
      }
    }
  }

  Map<String, ArMarkerVisibilityState> _nextStates({
    required List<ArMarkerModel> markers,
    required Set<String> visibleIds,
    required ArMarkerDeclutterState previousState,
    required DateTime now,
  }) {
    final next = <String, ArMarkerVisibilityState>{};
    for (final marker in markers) {
      final id = marker.infoObject.id;
      final isVisible = visibleIds.contains(id);
      final previous = previousState.markerStates[id];
      next[id] = ArMarkerVisibilityState(
        isVisible: isVisible,
        changedAt: previous == null || previous.isVisible != isVisible
            ? now
            : previous.changedAt,
      );
    }
    return next;
  }

  int _stableHiddenCount({
    required List<ArMarkerModel> markers,
    required Set<String> hiddenIds,
    required ArMarkerDeclutterState previousState,
  }) {
    final signature = _clusterSignature(markers);
    if (previousState.clusterSignature == signature &&
        previousState.hiddenIds.length == hiddenIds.length) {
      return previousState.hiddenByOverlap;
    }
    return hiddenIds.length;
  }

  String _clusterSignature(List<ArMarkerModel> markers) => [
    for (final marker in markers)
      '${marker.infoObject.id}@${(marker.normalizedX / minHorizontalSpacing).round()}:${(marker.top / minVerticalSpacing).round()}',
  ].join('|');

  ArMarkerModel? _selectedMarker(
    List<ArMarkerModel> markers,
    String? selectedInfoObjectId,
  ) {
    if (selectedInfoObjectId == null) return null;
    for (final marker in markers) {
      if (marker.infoObject.id == selectedInfoObjectId) return marker;
    }
    return null;
  }

  ArMarkerModel? _resolveOverlap(
    ArMarkerModel marker,
    List<ArMarkerModel> visible, {
    required bool isSelected,
  }) {
    final candidates = <ArMarkerModel>[
      marker,
      for (final offset in const [0.10, -0.10, 0.20, -0.16, 0.28, -0.24, 0.34])
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

  int _compareForStablePaint(ArMarkerModel a, ArMarkerModel b) {
    final x = a.normalizedX.compareTo(b.normalizedX);
    if (x != 0) return x;
    return compareDeterministic(a, b, null);
  }

  int compareDeterministic(
    ArMarkerModel a,
    ArMarkerModel b,
    String? selectedInfoObjectId,
  ) {
    final selected = _selectedRank(
      a,
      selectedInfoObjectId,
    ).compareTo(_selectedRank(b, selectedInfoObjectId));
    if (selected != 0) return selected;
    final severity = b.infoObject.warning.severity.compareTo(
      a.infoObject.warning.severity,
    );
    if (severity != 0) return severity;
    final sourcePriority = _sourcePriority(a).compareTo(_sourcePriority(b));
    if (sourcePriority != 0) return sourcePriority;
    final distance = (a.infoObject.distanceMeters ?? double.infinity).compareTo(
      b.infoObject.distanceMeters ?? double.infinity,
    );
    if (distance != 0) return distance;
    final createdAt = _createdAt(a).compareTo(_createdAt(b));
    if (createdAt != 0) return createdAt;
    return a.infoObject.id.compareTo(b.infoObject.id);
  }

  int _selectedRank(ArMarkerModel marker, String? selectedInfoObjectId) =>
      marker.infoObject.id == selectedInfoObjectId ? 0 : 1;

  int _sourcePriority(ArMarkerModel marker) {
    final source = marker.infoObject.sourceLabel.toLowerCase();
    if (source.contains('community')) return 0;
    if (source.contains('berlin verkehr')) return 1;
    if (source.contains('autobahn')) return 2;
    if (source.contains('wetter')) return 3;
    if (source.contains('ladestation')) return 4;
    return 9;
  }

  int _createdAt(ArMarkerModel marker) =>
      marker.infoObject.warning.validFrom?.millisecondsSinceEpoch ??
      9223372036854775807;

  bool _isTrafficHint(WarningType type) => switch (type) {
    WarningType.speedLimit ||
    WarningType.roadwork ||
    WarningType.notice => true,
    WarningType.speedCamera ||
    WarningType.weather ||
    WarningType.chargingStation => false,
  };
}
