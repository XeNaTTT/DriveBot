import '../../location/domain/location_status.dart';
import '../domain/ar_anchor_candidate_mapper.dart';
import '../domain/ar_anchor_projection.dart';
import '../domain/ar_geo_anchor_candidate.dart';
import '../domain/ar_info_object.dart';
import '../domain/ar_marker_declutter.dart';
import '../domain/ar_marker_model.dart';
import '../domain/ar_projection_mapper.dart';
import '../domain/ar_projection_smoothing.dart';
import '../domain/ar_runtime_state.dart';
import '../domain/ar_world_anchor_state.dart';
import 'geo_ar_coordinate_mapper.dart';

final class ArAnchorProjectionResult {
  const ArAnchorProjectionResult({
    required this.markers,
    required this.candidates,
    required this.projections,
    required this.statusLabel,
    required this.hiddenByOverlap,
    required this.hiddenByFov,
    required this.hiddenByTracking,
    required this.projectionSourceLabel,
    this.lastRecalibrationAgeSeconds,
    this.declutterState = const ArMarkerDeclutterState(),
    this.projectedMarkers = const {},
  });

  final List<ArMarkerModel> markers;
  final List<ArGeoAnchorCandidate> candidates;
  final List<ArAnchorProjection> projections;
  final String statusLabel;
  final int hiddenByOverlap;
  final int hiddenByFov;
  final int hiddenByTracking;
  final String projectionSourceLabel;
  final double? lastRecalibrationAgeSeconds;
  final ArMarkerDeclutterState declutterState;
  final Map<String, ArMarkerModel> projectedMarkers;
}

final class ArAnchorProjectionService {
  const ArAnchorProjectionService({
    this.projectionMapper = const ArProjectionMapper(),
    this.candidateMapper = const ArAnchorCandidateMapper(),
    this.coordinateMapper = const GeoArCoordinateMapper(),
    this.declutter = const ArMarkerDeclutter(),
    this.smoothingConfig = const ArProjectionSmoothingConfig(),
  });

  final ArProjectionMapper projectionMapper;
  final ArAnchorCandidateMapper candidateMapper;
  final GeoArCoordinateMapper coordinateMapper;
  final ArMarkerDeclutter declutter;
  final ArProjectionSmoothingConfig smoothingConfig;

  ArAnchorProjectionResult project({
    required List<ArInfoObject> objects,
    required LocationStatus location,
    required ArRuntimeState runtimeState,
    Map<String, ArMarkerModel> previousMarkers = const {},
    Map<String, ArWorldAnchorState> nativeAnchorStates = const {},
    String? selectedInfoObjectId,
    ArMarkerDeclutterState previousDeclutterState =
        const ArMarkerDeclutterState(),
    DateTime? now,
  }) {
    final activeObjects = objects
        .where((object) => object.warning.isActiveAt(now ?? DateTime.now()))
        .toList(growable: false);
    final trackingLimited =
        runtimeState.trackingQuality == ArTrackingQuality.limited ||
        runtimeState.trackingQuality == ArTrackingQuality.unavailable;
    final fallbackMarkers = projectionMapper.project(
      objects: activeObjects,
      userHeadingDegrees: location.headingDegrees,
      devicePitchDegrees: runtimeState.devicePitchDegrees,
      deviceRollDegrees: runtimeState.deviceRollDegrees,
      trackingLimited: trackingLimited,
    );
    final hiddenByFov = activeObjects.length - fallbackMarkers.length;

    if (!location.hasLiveLocation) {
      final markers = fallbackMarkers
          .where((marker) => !marker.infoObject.warning.hasCoordinates)
          .toList(growable: false);
      return _result(
        markers: markers,
        previousMarkers: previousMarkers,
        selectedInfoObjectId: selectedInfoObjectId,
        previousDeclutterState: previousDeclutterState,
        now: now,
        candidates: const [],
        projections: const [],
        statusLabel:
            activeObjects.any((object) => object.warning.hasCoordinates)
            ? 'Standort erforderlich'
            : runtimeState.germanStatusLabel,
        hiddenByFov: hiddenByFov,
        projectionSourceLabel: 'fallback',
      );
    }

    final candidates = candidateMapper.geoCandidatesFromObjects(
      objects: activeObjects,
      location: location,
    );
    final geospatialIds = candidates.map((candidate) => candidate.id).toSet();

    if (candidates.isEmpty ||
        !runtimeState.shouldUseArKit ||
        !runtimeState.isRunning) {
      return _result(
        markers: fallbackMarkers,
        previousMarkers: previousMarkers,
        selectedInfoObjectId: selectedInfoObjectId,
        previousDeclutterState: previousDeclutterState,
        now: now,
        candidates: candidates,
        projections: const [],
        statusLabel: runtimeState.germanStatusLabel,
        hiddenByFov: hiddenByFov,
        projectionSourceLabel: 'fallback',
      );
    }

    if (runtimeState.trackingQuality == ArTrackingQuality.limited) {
      return _result(
        markers: fallbackMarkers
            .where((marker) => !geospatialIds.contains(marker.infoObject.id))
            .toList(growable: false),
        previousMarkers: previousMarkers,
        selectedInfoObjectId: selectedInfoObjectId,
        previousDeclutterState: previousDeclutterState,
        now: now,
        candidates: candidates,
        projections: const [],
        statusLabel: 'Tracking eingeschränkt',
        hiddenByFov: hiddenByFov,
        hiddenByTracking: geospatialIds.length,
        projectionSourceLabel: 'fallback',
      );
    }

    final objectById = {for (final object in activeObjects) object.id: object};
    final projections = candidates
        .map((candidate) {
          final object = objectById[candidate.id];
          if (object == null) return null;
          return _projectionFor(candidate, object, runtimeState, location);
        })
        .whereType<ArAnchorProjection>()
        .toList(growable: false);
    final candidateById = {
      for (final candidate in candidates) candidate.id: candidate,
    };
    final markerById = {
      for (final marker in fallbackMarkers) marker.infoObject.id: marker,
    };
    var hiddenByNativeFov = 0;
    var hiddenByTracking = 0;
    final anchoredMarkers = projections.map((projection) {
      final object = objectById[projection.candidate.id];
      final marker =
          markerById[projection.candidate.id] ??
          (object == null
              ? null
              : ArMarkerModel(
                  infoObject: object,
                  relativeBearing: projection.candidate.relativeBearing,
                  normalizedX: projection.normalizedX,
                  top: projection.top,
                  isWorldAnchored: projection.usesWorldAnchor,
                ));
      if (marker == null) return null;
      final nativeState = nativeAnchorStates[projection.candidate.id];
      if (nativeState != null && !nativeState.isVisible) {
        if (nativeState.hiddenReason == 'tracking') {
          hiddenByTracking++;
        } else if (nativeState.hiddenReason == 'fov') {
          hiddenByNativeFov++;
        }
        return null;
      }
      if (nativeState?.hasNativeScreenPosition == true) {
        return marker.copyWith(
          normalizedX: nativeState!.normalizedX,
          top: nativeState.top,
          isWorldAnchored: true,
        );
      }
      return marker.copyWith(
        normalizedX: projection.normalizedX,
        top: projection.top,
        isWorldAnchored: projection.usesWorldAnchor,
      );
    }).whereType<ArMarkerModel>();
    final retainedFallback = fallbackMarkers.where(
      (marker) => !candidateById.containsKey(marker.infoObject.id),
    );
    final markers = [...anchoredMarkers, ...retainedFallback];

    return _result(
      markers: markers,
      previousMarkers: previousMarkers,
      selectedInfoObjectId: selectedInfoObjectId,
      previousDeclutterState: previousDeclutterState,
      now: now,
      candidates: candidates,
      projections: projections,
      statusLabel: projections.any((projection) => projection.usesWorldAnchor)
          ? 'AR verankert'
          : runtimeState.germanStatusLabel,
      hiddenByFov: hiddenByFov + hiddenByNativeFov,
      hiddenByTracking: hiddenByTracking,
      projectionSourceLabel:
          nativeAnchorStates.values.any(
            (state) => state.hasNativeScreenPosition,
          )
          ? 'native'
          : 'fallback',
      lastRecalibrationAgeSeconds: _lastRecalibrationAge(nativeAnchorStates),
    );
  }

  ArAnchorProjectionResult _result({
    required List<ArMarkerModel> markers,
    required Map<String, ArMarkerModel> previousMarkers,
    required String? selectedInfoObjectId,
    required ArMarkerDeclutterState previousDeclutterState,
    required DateTime? now,
    required List<ArGeoAnchorCandidate> candidates,
    required List<ArAnchorProjection> projections,
    required String statusLabel,
    required int hiddenByFov,
    int hiddenByTracking = 0,
    String projectionSourceLabel = 'fallback',
    double? lastRecalibrationAgeSeconds,
  }) {
    final smoothed = _smooth(
      markers,
      previousMarkers,
      trackingLimited: statusLabel == 'Tracking eingeschränkt',
    );
    final decluttered = declutter.apply(
      markers: smoothed,
      selectedInfoObjectId: selectedInfoObjectId,
      previousState: previousDeclutterState,
      now: now,
    );
    return ArAnchorProjectionResult(
      markers: decluttered.visibleMarkers,
      candidates: candidates,
      projections: projections,
      statusLabel: statusLabel,
      hiddenByOverlap: decluttered.hiddenByOverlap,
      hiddenByFov: hiddenByFov,
      hiddenByTracking: hiddenByTracking,
      projectionSourceLabel: projectionSourceLabel,
      lastRecalibrationAgeSeconds: lastRecalibrationAgeSeconds,
      declutterState: decluttered.state,
      projectedMarkers: {
        for (final marker in smoothed) marker.infoObject.id: marker,
      },
    );
  }

  double? _lastRecalibrationAge(Map<String, ArWorldAnchorState> states) {
    final ages = states.values
        .map((state) => state.lastRecalibrationAgeSeconds)
        .whereType<double>();
    if (ages.isEmpty) return null;
    return ages.reduce((current, next) => current < next ? current : next);
  }

  ArAnchorProjection _projectionFor(
    ArGeoAnchorCandidate candidate,
    ArInfoObject object,
    ArRuntimeState runtimeState,
    LocationStatus location,
  ) {
    final local = coordinateMapper.localCoordinate(
      currentLatitude: location.latitude ?? 0,
      currentLongitude: location.longitude ?? 0,
      targetLatitude: candidate.latitude,
      targetLongitude: candidate.longitude,
      targetAltitude: candidate.altitude,
    );
    final arkit = coordinateMapper.arKitCoordinateFor(local);
    final halfFov = projectionMapper.horizontalFovDegrees / 2;
    final normalizedX = ((candidate.relativeBearing / halfFov) + 1) / 2;
    final top = projectionMapper.verticalPlacement.topFor(
      object: object,
      devicePitchDegrees: runtimeState.devicePitchDegrees,
      deviceRollDegrees: runtimeState.deviceRollDegrees,
      trackingLimited:
          runtimeState.trackingQuality == ArTrackingQuality.limited,
      targetAltitudeMeters: candidate.altitude,
    );
    return ArAnchorProjection(
      candidate: candidate,
      localCoordinate: local,
      arkitCoordinate: arkit,
      normalizedX: normalizedX.clamp(0, 1).toDouble(),
      top: top
          .clamp(projectionMapper.minTop, projectionMapper.maxTop)
          .toDouble(),
      usesWorldAnchor: runtimeState.trackingQuality == ArTrackingQuality.stable,
      currentLatitude: location.latitude ?? 0,
      currentLongitude: location.longitude ?? 0,
      currentHeadingDegrees: location.headingDegrees.toDouble(),
    );
  }

  List<ArMarkerModel> _smooth(
    Iterable<ArMarkerModel> markers,
    Map<String, ArMarkerModel> previousMarkers, {
    required bool trackingLimited,
  }) => markers
      .map((marker) {
        final previous = previousMarkers[marker.infoObject.id];
        if (previous == null) return marker;
        final alpha = trackingLimited
            ? smoothingConfig.limitedTrackingMarkerSmoothingFactor
            : smoothingConfig.markerSmoothingFactor;
        final xThreshold = ArProjectionSmoothing.normalizedMovementThreshold(
          pixelThreshold: smoothingConfig.minPixelMovementThreshold,
          extentPixels: 390,
        );
        final yThreshold = ArProjectionSmoothing.normalizedMovementThreshold(
          pixelThreshold: smoothingConfig.minPixelMovementThreshold,
          extentPixels: 844,
        );
        return marker.copyWith(
          normalizedX: ArProjectionSmoothing.smoothLinear(
            previous: previous.normalizedX,
            current: marker.normalizedX,
            factor: alpha,
            minChange: xThreshold,
          ),
          top: ArProjectionSmoothing.smoothLinear(
            previous: previous.top,
            current: marker.top,
            factor: alpha,
            minChange: yThreshold,
          ),
        );
      })
      .toList(growable: false);
}
