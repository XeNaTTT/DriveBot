import 'package:flutter/material.dart';

import '../domain/drive_telemetry.dart';
import '../domain/shift_advisor.dart';
import '../domain/vehicle_shift_profile.dart';

class DriveAssistantPanel extends StatelessWidget {
  const DriveAssistantPanel({
    required this.speedKph,
    this.currentGear,
    this.profile = VehicleShiftProfile.citroenJumper2020,
    this.bottomScrollPadding = 20,
    this.fillAvailableHeight = false,
    super.key,
  });

  final int speedKph;
  final int? currentGear;
  final VehicleShiftProfile profile;
  final double bottomScrollPadding;
  final bool fillAvailableHeight;

  @override
  Widget build(BuildContext context) {
    final gear = currentGear ?? ShiftAdvisor(profile).recommend(speedKph).gear;
    final telemetry = DriveTelemetryCalculator(
      profile,
    ).calculate(speedKph: speedKph, gear: gear);
    return Semantics(
      label:
          'Fahrassistenz, Gang $gear, ${telemetry.rpm} Umdrehungen pro Minute, ${telemetry.coachingText}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Container(
          key: const Key('drive-assistant-panel'),
          height: fillAvailableHeight ? double.infinity : null,
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: fillAvailableHeight ? double.infinity : 610,
          ),
          decoration: BoxDecoration(
            color: const Color(0xF20A1019),
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
            borderRadius: BorderRadius.circular(34),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 18, 20, bottomScrollPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(profile: profile, telemetry: telemetry),
                const SizedBox(height: 14),
                _CurveCard(profile: profile, telemetry: telemetry),
                const SizedBox(height: 14),
                _CoachingCard(telemetry: telemetry),
                if (telemetry.fact case final fact?) ...[
                  const SizedBox(height: 12),
                  _FactCard(fact: fact),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.telemetry});
  final VehicleShiftProfile profile;
  final DriveTelemetry telemetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF8CEBFF),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DRIVEBOT · FAHRASSISTENZ',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          _StatusPill(zone: telemetry.zone),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _Metric(value: '${telemetry.speedKph}', unit: 'KM/H GPS'),
          ),
          _Gear(gear: telemetry.gear),
          Expanded(
            child: _Metric(
              value: '${telemetry.rpm}',
              unit: 'U/MIN',
              alignEnd: true,
            ),
          ),
        ],
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.unit,
    this.alignEnd = false,
  });
  final String value;
  final String unit;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: .95,
        ),
      ),
      Text(
        unit,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white60,
          letterSpacing: 1.1,
        ),
      ),
    ],
  );
}

class _Gear extends StatelessWidget {
  const _Gear({required this.gear});
  final int gear;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('recommended-gear'),
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: .1),
      border: Border.all(color: Colors.white.withValues(alpha: .25)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$gear',
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: .9,
          ),
        ),
        const Text(
          'GANG',
          style: TextStyle(
            fontSize: 9,
            color: Colors.white60,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.zone});
  final EfficiencyZone zone;

  @override
  Widget build(BuildContext context) {
    final optimal = zone == EfficiencyZone.optimal;
    return Container(
      key: const Key('efficiency-status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (optimal ? const Color(0xFF30F29A) : const Color(0xFFFFB84D))
            .withValues(alpha: .18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: optimal ? const Color(0xFF30F29A) : const Color(0xFFFFB84D),
        ),
      ),
      child: Text(
        optimal ? 'OPTIMAL' : 'COACHING',
        style: TextStyle(
          color: optimal ? const Color(0xFF70FFC0) : const Color(0xFFFFCC77),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _CurveCard extends StatelessWidget {
  const _CurveCard({required this.profile, required this.telemetry});
  final VehicleShiftProfile profile;
  final DriveTelemetry telemetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
    decoration: _innerGlass,
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RADZUGKRAFT',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white60,
                letterSpacing: 1,
              ),
            ),
            Text(
              '${telemetry.tractiveForceNewton} N',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        SizedBox(
          key: const Key('drive-assistant-rpm-gauge'),
          height: 120,
          width: double.infinity,
          child: CustomPaint(painter: _ForceCurvePainter(profile, telemetry)),
        ),
      ],
    ),
  );
}

class _CoachingCard extends StatelessWidget {
  const _CoachingCard({required this.telemetry});
  final DriveTelemetry telemetry;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('coaching-card'),
    padding: const EdgeInsets.all(14),
    decoration: _innerGlass,
    child: Row(
      children: [
        Text(
          telemetry.arrowDirection,
          style: const TextStyle(
            color: Color(0xFF83E9FF),
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                telemetry.coachingText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Zielbereich 1.800–2.200 U/min',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.fact});
  final DriveFact fact;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('drive-fact-popup'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF77DFFF).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF77DFFF).withValues(alpha: .45)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb_rounded, color: Color(0xFF8CEBFF), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fact.title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fact.message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final _innerGlass = BoxDecoration(
  color: Colors.white.withValues(alpha: .075),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: Colors.white.withValues(alpha: .14)),
);

class _ForceCurvePainter extends CustomPainter {
  const _ForceCurvePainter(this.profile, this.telemetry);
  final VehicleShiftProfile profile;
  final DriveTelemetry telemetry;

  @override
  void paint(Canvas canvas, Size size) {
    final points = profile.tractiveForceCurves[telemetry.gear]!;
    const padding = 10.0;
    final plot = Rect.fromLTRB(
      padding,
      padding,
      size.width - padding,
      size.height - 16,
    );
    final minSpeed = points.first.speedKph;
    final maxSpeed = points.last.speedKph;
    final maxForce = points
        .map((point) => point.forceNewton)
        .reduce((a, b) => a > b ? a : b);
    Offset map(double speed, double force) => Offset(
      plot.left + (speed - minSpeed) / (maxSpeed - minSpeed) * plot.width,
      plot.bottom - force / maxForce * plot.height,
    );

    for (var i = 0; i < 4; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()..color = Colors.white.withValues(alpha: .08),
      );
    }
    final path = Path()
      ..moveTo(
        map(points.first.speedKph, points.first.forceNewton).dx,
        map(points.first.speedKph, points.first.forceNewton).dy,
      );
    for (final point in points.skip(1)) {
      final mapped = map(point.speedKph, point.forceNewton);
      path.lineTo(mapped.dx, mapped.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF72E6FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final pointer = map(
      telemetry.speedKph.clamp(minSpeed.round(), maxSpeed.round()).toDouble(),
      telemetry.tractiveForceNewton.toDouble(),
    );
    canvas.drawCircle(pointer, 9, Paint()..color = const Color(0xFF30F29A));
    canvas.drawCircle(pointer, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ForceCurvePainter oldDelegate) =>
      oldDelegate.telemetry.speedKph != telemetry.speedKph ||
      oldDelegate.telemetry.gear != telemetry.gear;
}
