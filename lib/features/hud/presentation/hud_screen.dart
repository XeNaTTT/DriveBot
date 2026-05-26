import 'package:flutter/material.dart';

import '../../data_sources/domain/data_source_registry.dart';
import '../../location/domain/location_repository.dart';
import '../../location/domain/location_status.dart';
import '../../location/domain/permission_repository.dart';
import '../../location/domain/sensor_permission_status.dart';
import '../domain/bearing_to_ar_position_mapper.dart';
import '../domain/hud_repository.dart';
import '../domain/hud_warning_item.dart';

class HudScreen extends StatefulWidget {
  const HudScreen({
    required this.hudRepository,
    required this.locationRepository,
    required this.dataSourceRegistry,
    required this.permissionRepository,
    this.arPositionMapper = const BearingToArPositionMapper(),
    super.key,
  });

  final HudRepository hudRepository;
  final LocationRepository locationRepository;
  final DataSourceRegistry dataSourceRegistry;
  final PermissionRepository permissionRepository;
  final BearingToArPositionMapper arPositionMapper;

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  HudWarningItem? _selectedWarning;

  @override
  Widget build(BuildContext context) {
    final location = widget.locationRepository.getCurrentStatus();
    final warnings = widget.hudRepository.getNearbyWarnings();
    final permissions = widget.permissionRepository.getCurrentPermissionStatus();
    final prioritizedWarnings = _prioritizeWarnings(warnings);
    final primaryWarning = prioritizedWarnings.isNotEmpty
        ? prioritizedWarnings.first
        : null;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 390 ? 12.0 : 16.0;
          return Stack(
            children: [
              const _CameraPlaceholderBackground(),
              ..._buildArMarkers(
                constraints: constraints,
                location: location,
                warnings: prioritizedWarnings,
              ),
              SafeArea(
                child: Semantics(
                  label: 'Heads-up driving dashboard',
                  child: Padding(
                    key: const Key('hud-root'),
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HudStatusBar(status: location),
                        const SizedBox(height: 10),
                        _HudPermissionFallback(status: permissions),
                        const SizedBox(height: 10),
                        _HudCenterOverlay(
                          warnings: warnings,
                          status: location,
                          priorityWarning: primaryWarning,
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _HudWarningList(
                            warnings: warnings,
                            selectedWarning: _selectedWarning,
                            onWarningTap: (warning) {
                              setState(() => _selectedWarning = warning);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildArMarkers({
    required BoxConstraints constraints,
    required LocationStatus location,
    required List<HudWarningItem> warnings,
  }) {
    final markerWidth = constraints.maxWidth < 390 ? 120.0 : 138.0;
    return warnings.take(3).map((warning) {
      final arPosition = widget.arPositionMapper.map(
        userHeadingDegrees: location.headingDegrees,
        warningBearingDegrees: warning.bearingDegrees,
        warningDistanceMeters: warning.distanceMeters,
      );
      final leftFactor = ((arPosition.horizontalAlignment + 1) / 2).clamp(
        0.08,
        0.92,
      );
      final top = (130 + ((1 - arPosition.verticalBias) * 180)).clamp(
        120.0,
        constraints.maxHeight - 200,
      );

      return Positioned(
        left: (leftFactor * constraints.maxWidth) - (markerWidth / 2),
        top: top,
        child: _ArWarningMarker(
          warning: warning,
          emphasized: warning == warnings.first,
          width: markerWidth,
        ),
      );
    }).toList();
  }

  List<HudWarningItem> _prioritizeWarnings(List<HudWarningItem> warnings) {
    final sorted = [...warnings]..sort((a, b) {
      final priorityCompare = _warningPriority(
        a.type,
      ).compareTo(_warningPriority(b.type));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return a.distanceMeters.compareTo(b.distanceMeters);
    });
    return sorted;
  }

  int _warningPriority(WarningType type) => switch (type) {
        WarningType.speedCamera => 0,
        WarningType.roadwork => 1,
        WarningType.speedLimit => 2,
        WarningType.weather => 3,
        WarningType.chargingStation => 4,
      };
}

class _CameraPlaceholderBackground extends StatelessWidget {
  const _CameraPlaceholderBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2A39), Color(0xFF0A0F14)],
        ),
      ),
      child: CustomPaint(painter: _HudGridPainter(), size: Size.infinite),
    );
  }
}

class _HudStatusBar extends StatelessWidget {
  const _HudStatusBar({required this.status});

  final LocationStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      key: const Key('hud-status-bar'),
      container: true,
      label: 'Current speed, heading, and GPS status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x3357E3FF)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatusChip(
                  label: 'Speed',
                  value: '${status.speedKph} km/h',
                  compact: compact,
                  theme: theme,
                ),
                _StatusChip(
                  label: 'Heading',
                  value: '${status.headingDegrees}° ${status.cardinalHeading}',
                  compact: compact,
                  theme: theme,
                ),
                _StatusChip(
                  label: 'GPS',
                  value: status.gpsFixStatus.name.toUpperCase(),
                  compact: compact,
                  theme: theme,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.compact,
    required this.theme,
  });
  final String label;
  final String value;
  final bool compact;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: compact ? 92 : 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Text(
            value,
            style: theme.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _HudPermissionFallback extends StatelessWidget {
  const _HudPermissionFallback({required this.status});

  final SensorPermissionStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.allGranted) return const SizedBox.shrink();

    return Semantics(
      key: const Key('permission-fallback'),
      label: 'Permission fallback mode is active',
      child: Material(
        color: const Color(0xFF3A1700),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Grant camera, location, and motion for full AR guidance.',
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x99FFA94D)),
            ),
            child: Text(
              'Limited mode: permissions are not fully granted. Using mock-safe fallback.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}

class _HudCenterOverlay extends StatelessWidget {
  const _HudCenterOverlay({
    required this.warnings,
    required this.status,
    required this.priorityWarning,
  });

  final List<HudWarningItem> warnings;
  final LocationStatus status;
  final HudWarningItem? priorityWarning;

  @override
  Widget build(BuildContext context) {
    final highestSeverity = warnings.isEmpty
        ? 0
        : warnings.map((w) => w.severity).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: const Color(0x6657E3FF), width: 1.2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useVerticalLayout = constraints.maxWidth < 480;
          final riskText = Text(
            'Risk $highestSeverity/5',
            style: Theme.of(context).textTheme.titleLarge,
          );
          final summary = _OverlaySummary(
            warnings: warnings,
            status: status,
            priorityWarning: priorityWarning,
          );
          if (useVerticalLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 8), riskText],
            );
          }
          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: 12),
              FittedBox(child: riskText),
            ],
          );
        },
      ),
    );
  }
}

class _OverlaySummary extends StatelessWidget {
  const _OverlaySummary({
    required this.warnings,
    required this.status,
    required this.priorityWarning,
  });
  final List<HudWarningItem> warnings;
  final LocationStatus status;
  final HudWarningItem? priorityWarning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DriveBot HUD', style: Theme.of(context).textTheme.titleLarge),
        Text(
          'Active alerts: ${warnings.length}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          priorityWarning == null
              ? 'Primary: no active warnings'
              : 'Primary: ${priorityWarning!.title} (${priorityWarning!.distanceMeters} m)',
          key: const Key('primary-warning-title'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          status.isSpeedEstimatedFromGps
              ? 'Speed source: GPS estimate'
              : 'Speed source: Mock fallback',
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _HudWarningList extends StatelessWidget {
  const _HudWarningList({
    required this.warnings,
    required this.selectedWarning,
    required this.onWarningTap,
  });

  final List<HudWarningItem> warnings;
  final HudWarningItem? selectedWarning;
  final ValueChanged<HudWarningItem> onWarningTap;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return const _HudEmptyState();
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: warnings.length,
      itemBuilder: (context, index) {
        final item = warnings[index];
        return _HudWarningCard(
          item: item,
          highlighted: selectedWarning == item || index == 0,
          onTap: () => onWarningTap(item),
          key: Key('warning-card-${item.type.name}'),
        );
      },
    );
  }
}

class _HudEmptyState extends StatelessWidget {
  const _HudEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        key: const Key('empty-warning-state'),
        label: 'No active warnings',
        child: Text(
          'No active alerts nearby.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _ArWarningMarker extends StatelessWidget {
  const _ArWarningMarker({
    required this.warning,
    required this.emphasized,
    required this.width,
  });

  final HudWarningItem warning;
  final bool emphasized;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: width),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _colorForWarning(warning.type),
            width: emphasized ? 2 : 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              warning.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${warning.distanceMeters} m',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForWarning(WarningType type) => switch (type) {
        WarningType.speedCamera => const Color(0xFFFF7B72),
        WarningType.speedLimit => const Color(0xFFFFC857),
        WarningType.roadwork => const Color(0xFFFFA94D),
        WarningType.weather => const Color(0xFF74C0FC),
        WarningType.chargingStation => const Color(0xFF63E6BE),
      };
}

class _HudWarningCard extends StatelessWidget {
  const _HudWarningCard({
    required this.item,
    required this.highlighted,
    required this.onTap,
    super.key,
  });

  final HudWarningItem item;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.type) {
      WarningType.speedCamera => const Color(0xFFFF7B72),
      WarningType.speedLimit => const Color(0xFFFFC857),
      WarningType.roadwork => const Color(0xFFFFA94D),
      WarningType.weather => const Color(0xFF74C0FC),
      WarningType.chargingStation => const Color(0xFF63E6BE),
    };

    return Semantics(
      label: '${item.title}. ${item.distanceMeters} meters away.',
      child: Card(
        color: Colors.black.withValues(alpha: highlighted ? 0.65 : 0.5),
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: color.withValues(alpha: highlighted ? 0.95 : 0.6),
            width: highlighted ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.distanceMeters} m',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HudGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x2257E3FF)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
