import 'package:flutter/material.dart';

import 'caravan_palette.dart';

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
    final w = size.width;
    final h = size.height;
    final expedition = model.id == 'offroad';
    final overcab = model.id == 'sport';
    final body = Path()..moveTo(w * .12, h * .76);
    if (overcab) {
      body
        ..lineTo(w * .12, h * .22)
        ..quadraticBezierTo(w * .12, h * .17, w * .19, h * .17)
        ..lineTo(w * .82, h * .17)
        ..quadraticBezierTo(w * .88, h * .17, w * .88, h * .31)
        ..lineTo(w * .76, h * .36);
    } else {
      body
        ..lineTo(w * .12, h * .31)
        ..quadraticBezierTo(w * .12, h * .22, w * .23, h * .22)
        ..lineTo(w * .66, h * .22)
        ..quadraticBezierTo(w * .72, h * .22, w * .76, h * .36);
    }
    body
      ..lineTo(w * .83, h * .51)
      ..lineTo(w * .91, h * .56)
      ..lineTo(w * .91, h * .76)
      ..close();
    final paintwork = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(model.color, Colors.white, .48)!,
        model.color,
        Color.lerp(model.color, Colors.black, .42)!,
      ],
      stops: const [0, .54, 1],
    );
    canvas.drawPath(
      body,
      Paint()..shader = paintwork.createShader(body.getBounds()),
    );
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
    final cabGlass = Path()
      ..moveTo(w * .67, h * .38)
      ..lineTo(w * .745, h * .38)
      ..lineTo(w * .805, h * .51)
      ..lineTo(w * .67, h * .51)
      ..close();
    canvas.drawPath(cabGlass, Paint()..color = const Color(0xFF15202C));
    canvas.drawRect(
      Rect.fromLTWH(w * .12, h * .62, w * .78, h * .048),
      Paint()..color = model.accent,
    );
    if (expedition) {
      final rack = Paint()..color = const Color(0xFF8D989D);
      canvas.drawRect(Rect.fromLTWH(w * .2, h * .17, w * .44, h * .045), rack);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * .26, h * .095, w * .23, h * .075),
          const Radius.circular(3),
        ),
        rack,
      );
    }
    for (final x in [.28, .73]) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * .79),
        h * (expedition ? .15 : .12),
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
