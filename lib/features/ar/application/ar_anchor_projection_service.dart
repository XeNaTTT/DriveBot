import 'dart:math' as math;

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
import 'geo_ar_coordinate_mapper.dart';

final class ArAnchorProjectionResult {
  const ArAnchorProjectionResult({
    required this.markers,
    required this.candidates,
    required this.projections,
    required this.statusLabel,
    required this.hiddenByOverlap,
    required this.hiddenByFov,
  });

  final List<ArMarkerModel> markers;
  final List<ArGeoAnchorCandidate> candidates;
  final List<ArAnchorProjection> projections;
  final String statusLabel;
  final int hiddenByOverlap;
  final int hiddenByFov;
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
    String? selectedInfoObjectId,
  }) {
    final trackingLimited =
        runtimeState.trackingQuality == ArTrackingQuality.limited ||
        runtimeState.trackingQuality == ArTrackingQuality.unavailable;
    final fallbackMarkers = projectionMapper.project(
      objects: objects,
      userHeadingDegrees: location.headingDegrees,
      devicePitchDegrees: runtimeState.devicePitchDegrees,
      deviceRollDegrees: runtimeState.deviceRollDegrees,
      trackingLimited: trackingLimited,
    );
    final hiddenByFov = objects.length - fallbackMarkers.length;

    if (!location.hasLiveLocation) {
      final markers = fallbackMarkers
          .where((marker) => !marker.infoObject.warning.hasCoordinates)
          .toList(growable: false);
      return _result(
        markers: markers,
        previousMarkers: previousMarkers,
        selectedInfoObjectId: selectedInfoObjectId,
        candidates: const [],
        projections: const [],
        statusLabel: objects.any((object) => object.warning.hasCoordinates)
            ? 'Standort erforderlich'
            : runtimeState.germanStatusLabel,
        hiddenByFov: hiddenByFov,
      );
    }

    final candidates = candidateMapper.geoCandidatesFromObjects(
      objects: objects,
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
        candidates: candidates,
        projections: const [],
        statusLabel: runtimeState.germanStatusLabel,
        hiddenByFov: hiddenByFov,
      );
    }

    if (runtimeState.trackingQuality == ArTrackingQuality.limited) {
      return _result(
        markers: fallbackMarkers
            .where((marker) => !geospatialIds.contains(marker.infoObject.id))
            .toList(growable: false),
        previousMarkers: previousMarkers,
        selectedInfoObjectId: selectedInfoObjectId,
        candidates: candidates,
        projections: const [],
        statusLabel: 'Tracking eingeschränkt',
        hiddenByFov: hiddenByFov,
      );
    }

    final objectById = {for (final object in objects) object.id: object};
    final projections = candidates
        .map((candidate) {
          final object = objectById[candidate.id];
          if (object == null) return null;
          return _projectionFor(candidate, object, runtimeState);
        })
        .whereType<ArAnchorProjection>()
        .toList(growable: false);
    final candidateById = {
      for (final candidate in candidates) candidate.id: candidate,
    };
    final markerById = {
      for (final marker in fallbackMarkers) marker.infoObject.id: marker,
    };
    final anchoredMarkers = projections.map((projection) {
      final marker = markerById[projection.candidate.id];
      if (marker == null) return null;
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
      candidates: candidates,
      projections: projections,
      statusLabel: projections.any((projection) => projection.usesWorldAnchor)
          ? 'AR verankert'
          : runtimeState.germanStatusLabel,
      hiddenByFov: hiddenByFov,
    );
  }

  ArAnchorProjectionResult _result({
    required List<ArMarkerModel> markers,
    required Map<String, ArMarkerModel> previousMarkers,
    required String? selectedInfoObjectId,
    required List<ArGeoAnchorCandidate> candidates,
    required List<ArAnchorProjection> projections,
    required String statusLabel,
    required int hiddenByFov,
  }) {
    final smoothed = _smooth(
      markers,
      previousMarkers,
      trackingLimited: statusLabel == 'Tracking eingeschränkt',
    );
    final decluttered = declutter.apply(
      markers: smoothed,
      selectedInfoObjectId: selectedInfoObjectId,
    );
    return ArAnchorProjectionResult(
      markers: decluttered.visibleMarkers,
      candidates: candidates,
      projections: projections,
      statusLabel: statusLabel,
      hiddenByOverlap: decluttered.hiddenByOverlap,
      hiddenByFov: hiddenByFov,
    );
  }

  ArAnchorProjection _projectionFor(
    ArGeoAnchorCandidate candidate,
    ArInfoObject object,
    ArRuntimeState runtimeState,
  ) {
    final local = ArLocalCoordinate(
      eastMeters: candidate.distanceMeters * _sinDeg(candidate.bearingDegrees),
      northMeters: candidate.distanceMeters * _cosDeg(candidate.bearingDegrees),
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

  double _sinDeg(double degrees) => math.sin(degrees * math.pi / 180);

  double _cosDeg(double degrees) => math.cos(degrees * math.pi / 180);
}
