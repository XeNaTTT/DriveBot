import 'package:flutter/material.dart';

import '../domain/caravan_model.dart';

class CaravanArt extends StatelessWidget {
  const CaravanArt({required this.model, this.compact = false, super.key});

  final CaravanModel model;
  final bool compact;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CaravanPainter(model),
    size: Size(compact ? 150 : 240, compact ? 86 : 132),
  );
}

class _CaravanPainter extends CustomPainter {
  const _CaravanPainter(this.model);

  final CaravanModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .88),
        width: size.width * .78,
        height: 18,
      ),
      shadow,
    );
    final body = Path()
      ..moveTo(size.width * .12, size.height * .66)
      ..quadraticBezierTo(
        size.width * .13,
        size.height * .25,
        size.width * .34,
        size.height * .18,
      )
      ..lineTo(size.width * .75, size.height * .18)
      ..quadraticBezierTo(
        size.width * .89,
        size.height * .26,
        size.width * .9,
        size.height * .65,
      )
      ..quadraticBezierTo(
        size.width * .88,
        size.height * .76,
        size.width * .78,
        size.height * .78,
      )
      ..lineTo(size.width * .2, size.height * .78)
      ..close();
    canvas.drawPath(body, Paint()..color = model.color);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .55),
    );
    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .28,
        size.height * .28,
        size.width * .36,
        size.height * .23,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(window, Paint()..color = const Color(0xFF15202C));
    canvas.drawRect(
      Rect.fromLTWH(size.width * .12, size.height * .62, size.width * .78, 7),
      Paint()..color = model.accent,
    );
    for (final x in [.28, .73]) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * .79),
        size.height * .13,
        Paint()..color = const Color(0xFF111419),
      );
      canvas.drawCircle(
        Offset(size.width * x, size.height * .79),
        size.height * .055,
        Paint()..color = const Color(0xFF77808A),
      );
    }
    canvas.drawCircle(
      Offset(size.width * .9, size.height * .57),
      4,
      Paint()..color = model.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _CaravanPainter oldDelegate) =>
      oldDelegate.model != model;
}
