import 'package:flutter/material.dart';

import '../../ar/domain/ar_projection_mapper.dart';
import '../../ar/presentation/ar_marker_layer.dart';
import '../../camera/presentation/camera_hud_background.dart';
import '../../data_sources/domain/data_source_registry.dart';
import '../../location/domain/location_repository.dart';
import '../../location/domain/location_status.dart';
import '../../location/domain/permission_repository.dart';
import '../../location/domain/sensor_permission_status.dart';
import '../../sensors/domain/sensor_runtime_state.dart';
import '../../warnings/domain/warning_repository.dart';
import '../../warnings/domain/warning_request.dart';
import '../domain/hud_repository.dart';
import '../domain/hud_warning_item.dart';

typedef CameraLayerBuilder = Widget Function(SensorPermissionStatus status);

class HudScreen extends StatefulWidget {
  const HudScreen({
    required this.hudRepository,
    required this.locationRepository,
    required this.dataSourceRegistry,
    required this.permissionRepository,
    this.projectionMapper = const ArProjectionMapper(),
    this.cameraLayerBuilder,
    super.key,
  });

  final HudRepository hudRepository;
  final LocationRepository locationRepository;
  final DataSourceRegistry dataSourceRegistry;
  final PermissionRepository permissionRepository;
  final ArProjectionMapper projectionMapper;
  final CameraLayerBuilder? cameraLayerBuilder;

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  @override
  void initState() {
    super.initState();
    final repository = widget.hudRepository;
    if (repository is WarningRepository) {
      (repository as WarningRepository)
          .getWarnings(const WarningRequest.fallback());
    }
  }

  @override
  Widget build(BuildContext context) {
    final warnings = [...widget.hudRepository.getNearbyWarnings()]
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    return ValueListenableBuilder(
      valueListenable: widget.locationRepository.locationStatusListenable,
      builder: (context, location, _) => ValueListenableBuilder(
        valueListenable: widget.permissionRepository.permissionStatusListenable,
        builder: (context, permissions, __) {
          final markers = widget.projectionMapper.project(
            warnings: warnings,
            userHeadingDegrees: location.headingDegrees,
          );
          final primary = markers.isNotEmpty
              ? markers.first.warning
              : (warnings.isEmpty ? null : warnings.first);
          final moreCount = markers.length > 1 ? markers.length - 1 : 0;
          final runtime = SensorRuntimeState(
            cameraAvailable:
                permissions.camera == SensorPermissionState.granted,
            locationStatus: location,
            permissionStatus: permissions,
            motionStatus: const MotionRuntimeState.unavailable(),
          );
          final source = widget.hudRepository is WarningDataSourceStatus &&
                  (widget.hudRepository as WarningDataSourceStatus)
                      .dataSourceLabel
                      .contains('Live')
              ? 'Live'
              : 'Fallback';

          return Scaffold(
            body: Stack(children: [
              widget.cameraLayerBuilder?.call(permissions) ??
                  CameraHudBackground(permissionStatus: permissions),
              ArMarkerLayer(markers: markers),
              SafeArea(
                child: Padding(
                  key: const Key('hud-root'),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [
                    _StatusBar(status: location, runtime: runtime),
                    const SizedBox(height: 8),
                    _RuntimePills(runtime: runtime),
                    const Spacer(),
                    if (moreCount > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          key: const Key('overflow-warning-count'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('+$moreCount more'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    _PrimaryCard(warning: primary, source: source),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status, required this.runtime});
  final LocationStatus status;
  final SensorRuntimeState runtime;
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('hud-status-bar'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text('${status.speedKph} km/h')),
          Flexible(
              child:
                  Text('${status.headingDegrees}° ${status.cardinalHeading}')),
          Flexible(child: Text(runtime.modeLabel, textAlign: TextAlign.end)),
        ]),
      );
}

class _RuntimePills extends StatelessWidget {
  const _RuntimePills({required this.runtime});

  final SensorRuntimeState runtime;

  @override
  Widget build(BuildContext context) {
    final messages = runtime.compactMessages.take(3).toList();
    if (messages.isEmpty || runtime.isFullyLiveMode) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        key: const Key('permission-fallback'),
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final message in messages) _StatusPill(message),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x99FFA94D)),
        ),
        child: Text(
          message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({required this.warning, required this.source});
  final HudWarningItem? warning;
  final String source;
  @override
  Widget build(BuildContext context) => SizedBox(
        key: const Key('primary-warning-card'),
        width: double.infinity,
        height: 84,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x6657E3FF)),
          ),
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(warning?.title ?? 'No active warnings',
                  key: const Key('primary-warning-title')),
              Text(warning == null
                  ? 'No instruction'
                  : '${warning!.distanceMeters} m · ${warning!.detail} · S${warning!.severity}'),
              Text('Source: $source',
                  key: const Key('warning-data-source-label')),
            ]),
          ),
        ),
      );
}
