import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/shift_advisor.dart';
import '../domain/vehicle_shift_profile.dart';

class DriveAssistantPanel extends StatelessWidget {
  const DriveAssistantPanel({
    required this.speedKph,
    this.profile = VehicleShiftProfile.citroenJumper2020,
    super.key,
  });

  final int speedKph;
  final VehicleShiftProfile profile;

  @override
  Widget build(BuildContext context) {
    final recommendation = ShiftAdvisor(profile).recommend(speedKph);
    return Semantics(
      label:
          'Schaltempfehlung Gang ${recommendation.gear}, ${recommendation.rpm} Umdrehungen pro Minute',
      child: Container(
        key: const Key('drive-assistant-panel'),
        constraints: const BoxConstraints(maxWidth: 390),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(
          color: const Color(0xEE07111C),
          border: Border.all(color: const Color(0xFF54E6A5), width: 2),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(profile.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 174,
              width: 300,
              child: CustomPaint(
                key: const Key('drive-assistant-rpm-gauge'),
                painter: _RpmGaugePainter(profile, recommendation.rpm),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${recommendation.rpm}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'U/min',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'GANG ${recommendation.gear}',
              key: const Key('recommended-gear'),
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: Color(0xFF54E6A5),
                letterSpacing: 2,
              ),
            ),
            Text(
              '$speedKph km/h · GPS',
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(color: Color(0xFF54E6A5), label: 'Sparen'),
                SizedBox(width: 20),
                _Legend(color: Color(0xFFFFB547), label: 'Max. Kraft'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _RpmGaugePainter extends CustomPainter {
  const _RpmGaugePainter(this.profile, this.rpm);
  final VehicleShiftProfile profile;
  final int rpm;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .9);
    final radius = math.min(size.width * .42, size.height * .76);
    const start = math.pi;
    const sweep = math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, start, sweep, false, base);
    void zone(int from, int to, Color color) {
      canvas.drawArc(
        rect,
        start + sweep * from / profile.maximumRpm,
        sweep * (to - from) / profile.maximumRpm,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );
    }

    zone(profile.ecoRpmStart, profile.ecoRpmEnd, const Color(0xFF54E6A5));
    zone(profile.powerRpmStart, profile.powerRpmEnd, const Color(0xFFFFB547));
    final angle =
        start + sweep * rpm.clamp(0, profile.maximumRpm) / profile.maximumRpm;
    final tip =
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 4);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RpmGaugePainter oldDelegate) =>
      oldDelegate.rpm != rpm || oldDelegate.profile != profile;
}
