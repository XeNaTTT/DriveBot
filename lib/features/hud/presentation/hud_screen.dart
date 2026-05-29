import 'dart:async';

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
import '../../reports/application/speed_camera_report_controller.dart';
import '../../reports/domain/speed_camera_report_type.dart';
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
    this.reportController,
    super.key,
  });

  final HudRepository hudRepository;
  final LocationRepository locationRepository;
  final DataSourceRegistry dataSourceRegistry;
  final PermissionRepository permissionRepository;
  final ArProjectionMapper projectionMapper;
  final CameraLayerBuilder? cameraLayerBuilder;
  final Widget? accountEntryPoint;
  final SpeedCameraReportController? reportController;

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  final InformationCategoryController _categoryController =
      InformationCategoryController();
  CameraRuntimeState _cameraState = const CameraRuntimeState.initializing();
  bool _showReportingChoices = false;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _categoryController.addListener(_handleCategoryFilterChanged);
    widget.reportController?.addListener(_handleReportControllerChanged);
    _loadWarnings();
  }

  @override
  void dispose() {
    _categoryController.removeListener(_handleCategoryFilterChanged);
    widget.reportController?.removeListener(_handleReportControllerChanged);
    _messageTimer?.cancel();
    _categoryController.dispose();
    super.dispose();
  }

  void _handleCategoryFilterChanged() {
    if (mounted) setState(() {});
  }

  void _handleReportControllerChanged() {
    if (!mounted) return;
    setState(() {});
    if (widget.reportController?.message != null) {
      _messageTimer?.cancel();
      _messageTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) widget.reportController?.clearMessage();
      });
    }
  }

  Future<void> _loadWarnings() async {
    final repository = widget.hudRepository;
    if (repository is! WarningRepository) return;

    final location = widget.locationRepository.locationStatusListenable.value;
    await (repository as WarningRepository).getWarnings(
      _warningRequestFor(location),
    );
    if (mounted) setState(() {});
  }

  WarningRequest _warningRequestFor(LocationStatus location) {
    final latitude = location.latitude;
    final longitude = location.longitude;
    if (!location.hasLiveLocation || latitude == null || longitude == null) {
      return const WarningRequest.fallback();
    }

    return WarningRequest(
      latitude: latitude,
      longitude: longitude,
      headingDegrees: location.headingDegrees,
    );
  }

  void _handleCameraStateChanged(CameraRuntimeState state) {
    if (!mounted || _cameraState.availability == state.availability) return;
    setState(() => _cameraState = state);
  }

  Future<void> _reportSpeedCamera({
    required SpeedCameraReportType type,
    required LocationStatus location,
    required SensorRuntimeState runtime,
  }) async {
    final controller = widget.reportController;
    if (controller == null) return;
    setState(() => _showReportingChoices = false);
    await controller.report(
      type: type,
      location: location,
      cameraState: _cameraState,
      runtime: runtime,
    );
    await _loadWarnings();
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
                if (widget.reportController != null)
                  _ReportOverlay(
                    showChoices: _showReportingChoices,
                    message: widget.reportController?.message,
                    isReporting: widget.reportController?.isReporting ?? false,
                    onOpenChoices: () => setState(
                      () => _showReportingChoices = !_showReportingChoices,
                    ),
                    onCancel: () =>
                        setState(() => _showReportingChoices = false),
                    onMobile: () => _reportSpeedCamera(
                      type: SpeedCameraReportType.mobile,
                      location: location,
                      runtime: runtime,
                    ),
                    onFixed: () => _reportSpeedCamera(
                      type: SpeedCameraReportType.fixed,
                      location: location,
                      runtime: runtime,
                    ),
                  ),
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

class _ReportOverlay extends StatelessWidget {
  const _ReportOverlay({
    required this.showChoices,
    required this.message,
    required this.isReporting,
    required this.onOpenChoices,
    required this.onCancel,
    required this.onMobile,
    required this.onFixed,
  });

  final bool showChoices;
  final String? message;
  final bool isReporting;
  final VoidCallback onOpenChoices;
  final VoidCallback onCancel;
  final VoidCallback onMobile;
  final VoidCallback onFixed;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 92, 12, 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message != null)
              _ReportMessage(message!)
            else if (showChoices)
              _ReportChoices(
                onMobile: isReporting ? null : onMobile,
                onFixed: isReporting ? null : onFixed,
                onCancel: onCancel,
              )
            else
              _ReportButton(enabled: !isReporting, onPressed: onOpenChoices),
          ],
        ),
      ),
    ),
  );
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('speed-camera-report-button'),
    height: 52,
    child: FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.add_alert_outlined),
      label: const Text('Blitzer melden'),
    ),
  );
}

class _ReportChoices extends StatelessWidget {
  const _ReportChoices({
    required this.onMobile,
    required this.onFixed,
    required this.onCancel,
  });

  final VoidCallback? onMobile;
  final VoidCallback? onFixed;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('speed-camera-report-choices'),
    constraints: const BoxConstraints(maxWidth: 230),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.68),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x8857E3FF)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceButton(label: 'Mobiler Blitzer', onPressed: onMobile),
        const SizedBox(height: 8),
        _ChoiceButton(label: 'Fester Blitzer', onPressed: onFixed),
        const SizedBox(height: 8),
        _ChoiceButton(label: 'Abbrechen', onPressed: onCancel),
      ],
    ),
  );
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: OutlinedButton(onPressed: onPressed, child: Text(label)),
  );
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('speed-camera-report-message'),
    constraints: const BoxConstraints(maxWidth: 310, minHeight: 44),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF63E6BE)),
    ),
    child: Text(
      message,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
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
