import 'package:flutter/material.dart';

import '../../ar/domain/ar_runtime_state.dart';
import '../../ar/presentation/arkit_camera_background.dart';
import '../../camera/domain/camera_runtime_state.dart';
import '../../camera/presentation/camera_hud_background.dart';
import '../../location/domain/sensor_permission_status.dart';

/// Provides the live device view used by the race.
///
/// ARKit world tracking is preferred on iOS. Other devices, and iOS devices
/// without ARKit support, keep the game playable over the rear-camera feed.
class ArRaceBackground extends StatefulWidget {
  const ArRaceBackground({super.key});

  @override
  State<ArRaceBackground> createState() => _ArRaceBackgroundState();
}

class _ArRaceBackgroundState extends State<ArRaceBackground> {
  static const _grantedPermissions = SensorPermissionStatus(
    camera: SensorPermissionState.granted,
    location: SensorPermissionState.unavailable,
    motion: SensorPermissionState.granted,
  );

  String _status = 'AR WIRD GESTARTET';
  bool _isLive = false;

  void _handleArState(ArRuntimeState state) {
    if (!mounted || !state.shouldUseArKit || !state.isRunning) return;
    setState(() {
      _status = 'ARKIT  •  LIVE';
      _isLive = true;
    });
  }

  void _handleCameraState(CameraRuntimeState state) {
    if (!mounted) return;
    setState(() {
      if (state.availability == CameraRuntimeAvailability.ready) {
        _status = 'KAMERA  •  LIVE';
        _isLive = true;
      } else if (state.shouldUseFallback) {
        _status = 'AR-FALLBACK';
        _isLive = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
    key: const Key('ar-race-background'),
    fit: StackFit.expand,
    children: [
      ArKitCameraBackground(
        permissionStatus: _grantedPermissions,
        onArStateChanged: _handleArState,
        onCameraStateChanged: _handleCameraState,
        fallbackBuilder: () => CameraHudBackground(
          permissionStatus: _grantedPermissions,
          onStateChanged: _handleCameraState,
        ),
      ),
      const IgnorePointer(child: CustomPaint(painter: _ArTrackGuidePainter())),
      SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _ArStatusBadge(label: _status, isLive: _isLive),
          ),
        ),
      ),
    ],
  );
}

class _ArStatusBadge extends StatelessWidget {
  const _ArStatusBadge({required this.label, required this.isLive});

  final String label;
  final bool isLive;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: label,
    child: Container(
      key: const Key('ar-runtime-status'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLive ? const Color(0xFFD8FF3E) : const Color(0xFFFFB74D),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLive ? Icons.view_in_ar_rounded : Icons.camera_alt_outlined,
            size: 16,
            color: isLive ? const Color(0xFFD8FF3E) : const Color(0xFFFFB74D),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

/// A sparse guide keeps the caravan grounded without obscuring the real room.
class _ArTrackGuidePainter extends CustomPainter {
  const _ArTrackGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = Offset(size.width / 2, size.height * .36);
    final guide = Paint()
      ..color = const Color(0x66D8FF3E)
      ..strokeWidth = 1.5;
    final shade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0x55000000)],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, shade);
    canvas.drawLine(horizon, Offset(size.width * .08, size.height), guide);
    canvas.drawLine(horizon, Offset(size.width * .92, size.height), guide);
    for (var y = .56; y < .9; y += .1) {
      final halfWidth = size.width * (y - .36) * .62;
      canvas.drawLine(
        Offset(horizon.dx - halfWidth, size.height * y),
        Offset(horizon.dx + halfWidth, size.height * y),
        guide,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
