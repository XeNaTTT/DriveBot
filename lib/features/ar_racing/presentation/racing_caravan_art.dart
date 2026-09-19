import 'package:flutter/material.dart';

import '../domain/caravan_model.dart';

/// Rear three-quarter view used while the caravan drives into the room.
class RacingCaravanArt extends StatelessWidget {
  const RacingCaravanArt({required this.model, super.key});

  final CaravanModel model;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('racing-caravan-3d'),
    painter: _RacingCaravanPainter(model),
    size: const Size(190, 132),
  );
}

class _RacingCaravanPainter extends CustomPainter {
  const _RacingCaravanPainter(this.model);

  final CaravanModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .87),
        width: size.width * .74,
        height: size.height * .18,
      ),
      shadow,
    );

    final side = Path()
      ..moveTo(size.width * .78, size.height * .18)
      ..lineTo(size.width * .91, size.height * .32)
      ..lineTo(size.width * .88, size.height * .75)
      ..lineTo(size.width * .75, size.height * .82)
      ..close();
    canvas.drawPath(
      side,
      Paint()..color = Color.lerp(model.color, Colors.black, .3)!,
    );

    final rear = Path()
      ..moveTo(size.width * .22, size.height * .24)
      ..quadraticBezierTo(
        size.width * .24,
        size.height * .13,
        size.width * .35,
        size.height * .1,
      )
      ..lineTo(size.width * .69, size.height * .1)
      ..quadraticBezierTo(
        size.width * .79,
        size.height * .14,
        size.width * .8,
        size.height * .25,
      )
      ..lineTo(size.width * .78, size.height * .78)
      ..lineTo(size.width * .2, size.height * .78)
      ..close();
    canvas.drawPath(rear, Paint()..color = model.color);
    canvas.drawPath(
      rear,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .65),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .3,
          size.height * .22,
          size.width * .39,
          size.height * .27,
        ),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFF15202C),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .2, size.height * .64, size.width * .58, 8),
      Paint()..color = model.accent,
    );
    for (final x in [.28, .72]) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * .81),
        size.height * .14,
        Paint()..color = const Color(0xFF0B0E13),
      );
      canvas.drawCircle(
        Offset(size.width * x, size.height * .81),
        size.height * .06,
        Paint()..color = const Color(0xFF7C8793),
      );
    }
    for (final x in [.28, .7]) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * .59),
        4,
        Paint()..color = const Color(0xFFFF5A36),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RacingCaravanPainter oldDelegate) =>
      oldDelegate.model != model;
}
