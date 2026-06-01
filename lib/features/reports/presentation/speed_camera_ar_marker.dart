import 'package:flutter/material.dart';

import '../../ar/domain/ar_info_object.dart';

class SpeedCameraArMarker extends StatelessWidget {
  const SpeedCameraArMarker({
    required this.infoObject,
    this.onTap,
    this.selected = false,
    super.key,
  });

  final ArInfoObject infoObject;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFF7B72);
    return Semantics(
      button: true,
      label:
          '${infoObject.title}, ${infoObject.formattedDistance}, Quelle Community',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 1,
              height: 16,
              color: color.withValues(alpha: 0.65),
            ),
            Container(
              key: const Key('speed-camera-ar-marker'),
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: selected ? 0.54 : 0.38),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: 0.95),
                  width: selected ? 1.8 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CustomPaint(
                      painter: _SpeedCameraSilhouettePainter(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayTitle(infoObject.title),
                          key: Key('speed-camera-label-${infoObject.title}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${infoObject.formattedDistance} · Quelle: Community',
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
      ),
    );
  }

  static String _displayTitle(String title) =>
      title == 'Mobiler Blitzer' || title == 'Fester Blitzer'
      ? title
      : 'Kamera';
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
