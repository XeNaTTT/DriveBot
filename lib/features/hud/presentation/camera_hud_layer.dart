import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../location/domain/sensor_permission_status.dart';

class CameraHudLayer extends StatelessWidget {
  const CameraHudLayer({required this.permissionStatus, super.key});

  final SensorPermissionStatus permissionStatus;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        permissionStatus.camera == SensorPermissionState.granted) {
      return const KeyedSubtree(
        key: Key('camera-preview-layer'),
        child: UiKitView(
          viewType: 'drivebot/camera_preview',
          layoutDirection: TextDirection.ltr,
        ),
      );
    }

    return const KeyedSubtree(
      key: Key('mock-background-layer'),
      child: _CameraPlaceholderBackground(),
    );
  }
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

class _HudGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x2257E3FF)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
