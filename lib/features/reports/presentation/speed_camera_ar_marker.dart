import 'package:flutter/material.dart';

import '../../hud/domain/hud_warning_item.dart';

class SpeedCameraArMarker extends StatelessWidget {
  const SpeedCameraArMarker({required this.warning, super.key});

  final HudWarningItem warning;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFF7B72);
    return Semantics(
      label:
          '${warning.title}, ${warning.distanceMeters} Meter, Quelle Community',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 1, height: 16, color: color.withValues(alpha: 0.65)),
          Container(
            key: const Key('speed-camera-ar-marker'),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.9), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CustomPaint(painter: _SpeedCameraSilhouettePainter()),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTitle(warning.title),
                        key: Key('speed-camera-label-${warning.title}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${_distanceLabel(warning.distanceMeters)} · Quelle: Community',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _displayTitle(String title) =>
      title == 'Mobiler Blitzer' || title == 'Fester Blitzer'
      ? title
      : 'Kamera';

  static String _distanceLabel(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class _SpeedCameraSilhouettePainter extends CustomPainter {
  const _SpeedCameraSilhouettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF7B72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.20,
        size.width * 0.48,
        size.height * 0.42,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, paint);
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.40),
      size.width * 0.10,
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.70, size.height * 0.31),
      Offset(size.width * 0.88, size.height * 0.24),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.70, size.height * 0.52),
      Offset(size.width * 0.88, size.height * 0.61),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.46, size.height * 0.62),
      Offset(size.width * 0.46, size.height * 0.84),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.30, size.height * 0.84),
      Offset(size.width * 0.62, size.height * 0.84),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
