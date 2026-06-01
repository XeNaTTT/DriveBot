import 'dart:math' as math;

import '../../location/domain/location_status.dart';
import '../domain/ar_anchor_candidate_mapper.dart';
import '../domain/ar_anchor_projection.dart';
import '../domain/ar_geo_anchor_candidate.dart';
import '../domain/ar_info_object.dart';
import '../domain/ar_marker_model.dart';
import '../domain/ar_projection_mapper.dart';
import '../domain/ar_runtime_state.dart';
import 'geo_ar_coordinate_mapper.dart';

final class ArAnchorProjectionResult {
  const ArAnchorProjectionResult({
    required this.markers,
    required this.candidates,
    required this.projections,
    required this.statusLabel,
  });

  final List<ArMarkerModel> markers;
  final List<ArGeoAnchorCandidate> candidates;
  final List<ArAnchorProjection> projections;
  final String statusLabel;
}

final class ArAnchorProjectionService {
  const ArAnchorProjectionService({
    this.projectionMapper = const ArProjectionMapper(),
    this.candidateMapper = const ArAnchorCandidateMapper(),
    this.coordinateMapper = const GeoArCoordinateMapper(),
  });

  final ArProjectionMapper projectionMapper;
  final ArAnchorCandidateMapper candidateMapper;
  final GeoArCoordinateMapper coordinateMapper;

  ArAnchorProjectionResult project({
    required List<ArInfoObject> objects,
    required LocationStatus location,
    required ArRuntimeState runtimeState,
    Map<String, ArMarkerModel> previousMarkers = const {},
  }) {
    final fallbackMarkers = projectionMapper.project(
      objects: objects,
      userHeadingDegrees: location.headingDegrees,
    );
    if (!location.hasLiveLocation) {
      final markers = fallbackMarkers
          .where((marker) => !marker.infoObject.warning.hasCoordinates)
          .toList(growable: false);
      return ArAnchorProjectionResult(
        markers: _smooth(markers, previousMarkers),
        candidates: const [],
        projections: const [],
        statusLabel: objects.any((object) => object.warning.hasCoordinates)
            ? 'Standort erforderlich'
            : runtimeState.germanStatusLabel,
      );
    }

    final candidates = candidateMapper.geoCandidatesFromObjects(
      objects: objects,
      location: location,
    );
    final geospatialIds = candidates.map((candidate) => candidate.id).toSet();

    if (candidates.isEmpty || !runtimeState.shouldUseArKit) {
      return ArAnchorProjectionResult(
        markers: _smooth(fallbackMarkers, previousMarkers),
        candidates: candidates,
        projections: const [],
        statusLabel: runtimeState.germanStatusLabel,
      );
    }

    if (runtimeState.trackingQuality == ArTrackingQuality.limited) {
      return ArAnchorProjectionResult(
        markers: _smooth(
          fallbackMarkers
              .where((marker) => !geospatialIds.contains(marker.infoObject.id))
              .toList(growable: false),
          previousMarkers,
        ),
        candidates: candidates,
        projections: const [],
        statusLabel: 'Tracking eingeschränkt',
      );
    }

    final projections = candidates
        .map((candidate) => _projectionFor(candidate, runtimeState))
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

    return ArAnchorProjectionResult(
      markers: _smooth(markers, previousMarkers),
      candidates: candidates,
      projections: projections,
      statusLabel: projections.any((projection) => projection.usesWorldAnchor)
          ? 'AR verankert'
          : runtimeState.germanStatusLabel,
    );
  }

  ArAnchorProjection _projectionFor(
    ArGeoAnchorCandidate candidate,
    ArRuntimeState runtimeState,
  ) {
    final local = ArLocalCoordinate(
      eastMeters: candidate.distanceMeters * _sinDeg(candidate.bearingDegrees),
      northMeters: candidate.distanceMeters * _cosDeg(candidate.bearingDegrees),
    );
    final arkit = coordinateMapper.arKitCoordinateFor(local);
    final halfFov = projectionMapper.horizontalFovDegrees / 2;
    final normalizedX = ((candidate.relativeBearing / halfFov) + 1) / 2;
    final clampedDistance = candidate.distanceMeters.clamp(75, 3000);
    final depth = 1 - ((clampedDistance - 75) / (3000 - 75));
    final top =
        projectionMapper.minTop +
        ((projectionMapper.maxTop - projectionMapper.minTop) * depth);
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
    Map<String, ArMarkerModel> previousMarkers,
  ) => markers
      .map((marker) {
        final previous = previousMarkers[marker.infoObject.id];
        if (previous == null) return marker;
        const alpha = 0.35;
        return marker.copyWith(
          normalizedX:
              previous.normalizedX +
              ((marker.normalizedX - previous.normalizedX) * alpha),
          top: previous.top + ((marker.top - previous.top) * alpha),
        );
      })
      .toList(growable: false);

  double _sinDeg(double degrees) => math.sin(degrees * math.pi / 180);

  double _cosDeg(double degrees) => math.cos(degrees * math.pi / 180);
}
