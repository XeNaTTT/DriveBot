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
          child: Semantics(
            label: 'Radzugkraft-Diagramm mit Newton-Skala links',
            image: true,
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _ForceCurvePainter(profile, telemetry),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 2, 4, 2),
          child: Row(
            key: Key('efficiency-zone-legend'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: Color(0xFF30F29A), label: 'ECO-ZIEL'),
              SizedBox(width: 18),
              _LegendItem(color: Color(0xFFFFB84D), label: 'AUSSERHALB'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: .6,
        ),
      ),
    ],
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
    const scaleWidth = 38.0;
    final plot = Rect.fromLTRB(
      scaleWidth,
      12,
      size.width - 8,
      size.height - 14,
    );
    final minSpeed = points.first.speedKph;
    final maxSpeed = points.last.speedKph;
    final curveMaximum = points
        .map((point) => point.forceNewton)
        .reduce((a, b) => a > b ? a : b);
    final maxForce = (curveMaximum / 1000).ceil() * 1000.0;
    Offset map(double speed, double force) => Offset(
      plot.left + (speed - minSpeed) / (maxSpeed - minSpeed) * plot.width,
      plot.bottom - force / maxForce * plot.height,
    );

    final ecoStartSpeed = profile.speedKphAtRpm(
      rpm: profile.ecoRpmStart,
      gear: telemetry.gear,
    );
    final ecoEndSpeed = profile.speedKphAtRpm(
      rpm: profile.ecoRpmEnd,
      gear: telemetry.gear,
    );
    final ecoLeft = map(ecoStartSpeed.clamp(minSpeed, maxSpeed), 0).dx;
    final ecoRight = map(ecoEndSpeed.clamp(minSpeed, maxSpeed), 0).dx;
    final chartBackground = RRect.fromRectAndRadius(
      plot,
      const Radius.circular(10),
    );
    canvas.drawRRect(
      chartBackground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x2430F29A), Color(0x08FFFFFF)],
        ).createShader(plot),
    );

    if (ecoRight > ecoLeft) {
      final ecoBand = RRect.fromRectAndRadius(
        Rect.fromLTRB(ecoLeft, plot.top, ecoRight, plot.bottom),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        ecoBand,
        Paint()..color = const Color(0xFF30F29A).withValues(alpha: .13),
      );
      canvas.drawLine(
        Offset(ecoLeft, plot.top),
        Offset(ecoLeft, plot.bottom),
        Paint()..color = const Color(0xFF30F29A).withValues(alpha: .45),
      );
      canvas.drawLine(
        Offset(ecoRight, plot.top),
        Offset(ecoRight, plot.bottom),
        Paint()..color = const Color(0xFF30F29A).withValues(alpha: .45),
      );
    }

    for (var i = 0; i <= 4; i++) {
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()..color = Colors.white.withValues(alpha: .08),
      );
      _paintScaleLabel(
        canvas,
        value: maxForce * (4 - i) / 4,
        y: y,
        right: plot.left - 7,
      );
    }
    _paintUnitLabel(canvas, right: plot.left - 7, top: 0);

    final mappedPoints = points
        .map((point) => map(point.speedKph, point.forceNewton))
        .toList(growable: false);
    final path = _smoothPath(mappedPoints);
    final fillPath = Path.from(path)
      ..lineTo(mappedPoints.last.dx, plot.bottom)
      ..lineTo(mappedPoints.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66FFB84D), Color(0x08FFB84D)],
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFB84D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (ecoRight > ecoLeft) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(ecoLeft, plot.top, ecoRight, plot.bottom));
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x7730F29A), Color(0x0A30F29A)],
          ).createShader(plot),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF30F29A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }
    final pointer = map(
      telemetry.speedKph.clamp(minSpeed.round(), maxSpeed.round()).toDouble(),
      telemetry.tractiveForceNewton.toDouble(),
    );
    canvas.drawCircle(pointer, 9, Paint()..color = const Color(0xFF30F29A));
    canvas.drawCircle(pointer, 4, Paint()..color = Colors.white);
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final midpointX = (current.dx + next.dx) / 2;
      path.cubicTo(midpointX, current.dy, midpointX, next.dy, next.dx, next.dy);
    }
    return path;
  }

  void _paintScaleLabel(
    Canvas canvas, {
    required double value,
    required double y,
    required double right,
  }) {
    final label = value >= 1000
        ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k'
        : value.toStringAsFixed(0);
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xB3FFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(right - painter.width, y - painter.height / 2),
    );
  }

  void _paintUnitLabel(
    Canvas canvas, {
    required double right,
    required double top,
  }) {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Color(0x99FFFFFF),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(right - painter.width, top));
  }

  @override
  bool shouldRepaint(covariant _ForceCurvePainter oldDelegate) =>
      oldDelegate.telemetry.speedKph != telemetry.speedKph ||
      oldDelegate.telemetry.gear != telemetry.gear;
}
