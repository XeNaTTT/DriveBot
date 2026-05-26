import 'package:flutter/material.dart';

import '../../data_sources/domain/data_source_registry.dart';
import '../../location/domain/location_repository.dart';
import '../../location/domain/location_status.dart';
import '../../location/domain/permission_repository.dart';
import '../../location/domain/sensor_permission_status.dart';
import '../domain/bearing_to_ar_position_mapper.dart';
import '../domain/hud_repository.dart';
import '../domain/hud_warning_item.dart';

class HudScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final location = locationRepository.getCurrentStatus();
    final warnings = hudRepository.getNearbyWarnings();
    final permissions = permissionRepository.getCurrentPermissionStatus();
    final prioritizedWarnings = _prioritizeWarnings(warnings);

    return Scaffold(
      body: Stack(
        children: [
          _CameraPlaceholderBackground(),
          ..._buildArMarkers(location, prioritizedWarnings),
          SafeArea(
            child: Column(
              children: [
                _TopStatusBar(status: location),
                const SizedBox(height: 12),
                _PermissionBanner(status: permissions),
                const SizedBox(height: 10),
                _HudCenterOverlay(warnings: warnings, status: location, priorityWarning: prioritizedWarnings.first),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: warnings.length,
                    itemBuilder: (context, index) => _WarningCard(item: warnings[index]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildArMarkers(LocationStatus location, List<HudWarningItem> warnings) {
    return warnings.take(3).map((warning) {
      final arPosition = arPositionMapper.map(
        userHeadingDegrees: location.headingDegrees,
        warningBearingDegrees: warning.bearingDegrees,
        warningDistanceMeters: warning.distanceMeters,
      );
      final leftFactor = ((arPosition.horizontalAlignment + 1) / 2).clamp(0.05, 0.95);
      final top = 160 + ((1 - arPosition.verticalBias) * 180);

      return Positioned(
        left: (leftFactor * 340) - 72,
        top: top,
        child: _ArWarningMarker(
          warning: warning,
          emphasized: warning == warnings.first,
        ),
      );
    }).toList();
  }

  List<HudWarningItem> _prioritizeWarnings(List<HudWarningItem> warnings) {
    final sorted = [...warnings]..sort((a, b) {
      final priorityCompare = _warningPriority(a.type).compareTo(_warningPriority(b.type));
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
      child: CustomPaint(
        painter: _HudGridPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar({required this.status});

  final LocationStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x3357E3FF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${status.speedKph} km/h', style: Theme.of(context).textTheme.titleLarge),
          Text('${status.headingDegrees}° ${status.cardinalHeading}',
              style: Theme.of(context).textTheme.titleMedium),
          Text('GPS ${status.gpsFixStatus.name.toUpperCase()}',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.status});

  final SensorPermissionStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.allGranted) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1700),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x99FFA94D)),
      ),
      child: const Text(
        'Limited mode: camera/location/motion permissions are not fully granted. Using mock-safe fallback.',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HudCenterOverlay extends StatelessWidget {
  const _HudCenterOverlay({required this.warnings, required this.status, required this.priorityWarning});

  final List<HudWarningItem> warnings;
  final LocationStatus status;
  final HudWarningItem priorityWarning;

  @override
  Widget build(BuildContext context) {
    final highestSeverity = warnings.map((w) => w.severity).fold<int>(1, (a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: const Color(0x6657E3FF), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DriveAssistant AR', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('Active alerts: ${warnings.length}', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text('Primary: ${priorityWarning.title} (${priorityWarning.distanceMeters} m)',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(status.isSpeedEstimatedFromGps ? 'Speed source: GPS estimate' : 'Speed source: Mock fallback',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          Text('Risk $highestSeverity/5', style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _ArWarningMarker extends StatelessWidget {
  const _ArWarningMarker({required this.warning, required this.emphasized});

  final HudWarningItem warning;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: emphasized ? 144 : 128,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colorForWarning(warning.type), width: emphasized ? 2 : 1.2),
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
          Text('${warning.distanceMeters} m', style: const TextStyle(fontSize: 12)),
        ],
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

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.item});

  final HudWarningItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.type) {
      WarningType.speedCamera => const Color(0xFFFF7B72),
      WarningType.speedLimit => const Color(0xFFFFC857),
      WarningType.roadwork => const Color(0xFFFFA94D),
      WarningType.weather => const Color(0xFF74C0FC),
      WarningType.chargingStation => const Color(0xFF63E6BE),
    };

    return Card(
      color: Colors.black.withValues(alpha: 0.5),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Icon(Icons.warning_amber_rounded, color: color, size: 30),
        title: Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        subtitle: Text(item.detail, style: const TextStyle(fontSize: 15)),
        trailing: Text('${item.distanceMeters} m', style: const TextStyle(fontSize: 16)),
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
