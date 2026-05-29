import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ar/domain/ar_projection_mapper.dart';
import '../../ar/presentation/ar_marker_layer.dart';
import '../../camera/domain/camera_runtime_state.dart';
import '../../camera/presentation/camera_hud_background.dart';
import '../../data_sources/domain/data_source_registry.dart';
import '../../filters/application/information_category_controller.dart';
import '../../filters/domain/information_category.dart';
import '../../filters/presentation/category_filter_button.dart';
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
    this.accountEntryPoint,
    super.key,
  });

  final HudRepository hudRepository;
  final LocationRepository locationRepository;
  final DataSourceRegistry dataSourceRegistry;
  final PermissionRepository permissionRepository;
  final ArProjectionMapper projectionMapper;
  final CameraLayerBuilder? cameraLayerBuilder;
  final Widget? accountEntryPoint;

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  final InformationCategoryController _categoryController =
      InformationCategoryController();
  CameraRuntimeState _cameraState = const CameraRuntimeState.initializing();

  @override
  void initState() {
    super.initState();
    _categoryController.addListener(_handleCategoryFilterChanged);
    _loadWarnings();
  }

  @override
  void dispose() {
    _categoryController.removeListener(_handleCategoryFilterChanged);
    _categoryController.dispose();
    super.dispose();
  }

  void _handleCategoryFilterChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadWarnings() async {
    final repository = widget.hudRepository;
    if (repository is! WarningRepository) return;

    await (repository as WarningRepository).getWarnings(
      const WarningRequest.fallback(),
    );
    if (mounted) setState(() {});
  }

  void _handleCameraStateChanged(CameraRuntimeState state) {
    if (!mounted || _cameraState.availability == state.availability) return;
    setState(() => _cameraState = state);
  }

  Widget _buildCameraLayer(SensorPermissionStatus permissions) {
    final customBuilder = widget.cameraLayerBuilder;
    if (customBuilder != null) return customBuilder(permissions);

    return CameraHudBackground(
      permissionStatus: permissions,
      onStateChanged: _handleCameraStateChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allWarnings = [...widget.hudRepository.getNearbyWarnings()]
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    final warnings = allWarnings
        .where(
          (warning) =>
              _categoryController.isActive(warning.informationCategory),
        )
        .toList(growable: false);

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
            cameraAvailable: _cameraState.cameraAvailable,
            locationStatus: location,
            permissionStatus: permissions,
            motionStatus: const MotionRuntimeState.unavailable(),
          );
          final warningSource = widget.hudRepository is WarningDataSourceStatus
              ? widget.hudRepository as WarningDataSourceStatus
              : null;
          final source = warningSource?.dataSourceLabel ?? 'Fallback-Daten';

          return Scaffold(
            body: Stack(
              children: [
                _buildCameraLayer(permissions),
                ArMarkerLayer(markers: markers),
                SafeArea(
                  child: Padding(
                    key: const Key('hud-root'),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _StatusBar(
                                status: location,
                                runtime: runtime,
                              ),
                            ),
                            const SizedBox(width: 8),
                            CategoryFilterButton(
                              controller: _categoryController,
                            ),
                            if (widget.accountEntryPoint != null) ...[
                              const SizedBox(width: 8),
                              widget.accountEntryPoint!,
                            ],
                          ],
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 8),
                          _DebugSourceIndicator(
                            cameraState: _cameraState,
                            location: location,
                            warningSource: warningSource,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _RuntimePills(runtime: runtime),
                        if (runtime.isFallbackMode) ...[
                          const SizedBox(height: 8),
                          const _FallbackGuidance(),
                        ],
                        const Spacer(),
                        if (moreCount > 0)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              key: const Key('overflow-warning-count'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('+$moreCount weitere'),
                            ),
                          ),
                        const SizedBox(height: 8),
                        _PrimaryCard(
                          warning: primary,
                          source: source,
                          hasActiveCategories:
                              _categoryController.hasActiveCategories,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text('Tempo ${status.speedKph} km/h')),
        Flexible(
          child: Text(
            'Richtung ${status.headingDegrees}° ${status.cardinalHeading}',
          ),
        ),
        Flexible(
          child: Text('Modus ${runtime.modeLabel}', textAlign: TextAlign.end),
        ),
      ],
    ),
  );
}

class _DebugSourceIndicator extends StatelessWidget {
  const _DebugSourceIndicator({
    required this.cameraState,
    required this.location,
    required this.warningSource,
  });

  final CameraRuntimeState cameraState;
  final LocationStatus location;
  final WarningDataSourceStatus? warningSource;

  @override
  Widget build(BuildContext context) {
    final cameraLabel = cameraState.cameraAvailable ? 'Live' : 'Fallback';
    final locationLabel = location.hasLiveLocation && !location.isMock
        ? 'Live'
        : 'Fallback';
    final warningLabel = warningSource?.debugDataSourceLabel ?? 'Mock';

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        key: const Key('debug-source-indicator'),
        spacing: 6,
        runSpacing: 6,
        children: [
          _DebugSourcePill('Kamera: $cameraLabel'),
          _DebugSourcePill('Standort: $locationLabel'),
          _DebugSourcePill('Warnungen: $warningLabel'),
        ],
      ),
    );
  }
}

class _DebugSourcePill extends StatelessWidget {
  const _DebugSourcePill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0x8857E3FF)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
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
        children: [for (final message in messages) _StatusPill(message)],
      ),
    );
  }
}

class _FallbackGuidance extends StatelessWidget {
  const _FallbackGuidance();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      key: const Key('fallback-guidance'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x99FFA94D)),
      ),
      child: const Text(
        'Fallback aktiv: Erlaube Kamera, Standort und Bewegung für Live-AR.',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
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
    child: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
    required this.warning,
    required this.source,
    required this.hasActiveCategories,
  });
  final HudWarningItem? warning;
  final String source;
  final bool hasActiveCategories;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasActiveCategories
                  ? warning?.title ?? 'Keine aktiven Warnungen'
                  : 'Keine Kategorien aktiv',
              key: const Key('primary-warning-title'),
            ),
            Text(
              warning == null
                  ? (hasActiveCategories
                        ? 'Keine Anweisung'
                        : 'Filter anpassen')
                  : '${warning!.distanceMeters} m · ${warning!.detail} · S${warning!.severity}',
            ),
            Text(
              'Quelle: $source',
              key: const Key('warning-data-source-label'),
            ),
          ],
        ),
      ),
    ),
  );
}
