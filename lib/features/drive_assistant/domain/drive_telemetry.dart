import 'vehicle_shift_profile.dart';

enum EfficiencyZone { turboLagWarning, transition, optimal, highRpm, overRev }

class DriveFact {
  const DriveFact({required this.title, required this.message});
  final String title;
  final String message;
}

class DriveTelemetry {
  const DriveTelemetry({
    required this.speedKph,
    required this.gear,
    required this.rpm,
    required this.tractiveForceNewton,
    required this.zone,
    required this.coachingText,
    required this.arrowDirection,
    this.fact,
  });

  final int speedKph;
  final int gear;
  final int rpm;
  final int tractiveForceNewton;
  final EfficiencyZone zone;
  final String coachingText;
  final String arrowDirection;
  final DriveFact? fact;
}

class DriveTelemetryCalculator {
  const DriveTelemetryCalculator(this.profile);
  final VehicleShiftProfile profile;

  DriveTelemetry calculate({required int speedKph, required int gear}) {
    final safeGear = gear.clamp(1, profile.gearRatios.length);
    final rpm = _rpmFor(speedKph, safeGear);
    final zone = _zoneFor(rpm);
    return DriveTelemetry(
      speedKph: speedKph,
      gear: safeGear,
      rpm: rpm,
      tractiveForceNewton: _forceFor(speedKph, safeGear).round(),
      zone: zone,
      coachingText: _coachingFor(zone),
      arrowDirection: _arrowFor(zone),
      fact: _factFor(speedKph, safeGear, rpm),
    );
  }

  int _rpmFor(int speedKph, int gear) =>
      (speedKph *
              profile.gearRatios[gear - 1] *
              profile.finalDriveRatio *
              1000 /
              (60 * profile.wheelCircumferenceMeters))
          .round();

  double _forceFor(int speedKph, int gear) {
    final points = profile.tractiveForceCurves[gear]!;
    if (speedKph <= points.first.speedKph) return points.first.forceNewton;
    if (speedKph >= points.last.speedKph) return points.last.forceNewton;
    for (var index = 1; index < points.length; index++) {
      final right = points[index];
      if (speedKph <= right.speedKph) {
        final left = points[index - 1];
        final progress =
            (speedKph - left.speedKph) / (right.speedKph - left.speedKph);
        return left.forceNewton +
            (right.forceNewton - left.forceNewton) * progress;
      }
    }
    return points.last.forceNewton;
  }

  EfficiencyZone _zoneFor(int rpm) {
    if (rpm < 1500) return EfficiencyZone.turboLagWarning;
    if (rpm < profile.ecoRpmStart) return EfficiencyZone.transition;
    if (rpm <= profile.ecoRpmEnd) return EfficiencyZone.optimal;
    if (rpm > 3200) return EfficiencyZone.overRev;
    if (rpm > 2600) return EfficiencyZone.highRpm;
    return EfficiencyZone.transition;
  }

  String _coachingFor(EfficiencyZone zone) => switch (zone) {
    EfficiencyZone.turboLagWarning => 'Niedrigeren Gang wählen',
    EfficiencyZone.optimal => 'Drehzahl halten',
    EfficiencyZone.highRpm ||
    EfficiencyZone.overRev => 'Hochschalten oder Tempo reduzieren',
    EfficiencyZone.transition => 'Ruhig in den Sweet Spot fahren',
  };

  String _arrowFor(EfficiencyZone zone) => switch (zone) {
    EfficiencyZone.turboLagWarning => '▼',
    EfficiencyZone.highRpm || EfficiencyZone.overRev => '▼',
    EfficiencyZone.optimal => '●',
    EfficiencyZone.transition => '▲',
  };

  DriveFact? _factFor(int speedKph, int gear, int rpm) {
    if (gear == 6 && speedKph < 105 && rpm < 1750) {
      return const DriveFact(
        title: 'ÜBERLAPPUNGSBEREICH STEIGUNG',
        message:
            'Im 6. Gang fällt die Zugkraft ab. Bei 100 km/h bringt Gang 5 sofort über 2.100 N.',
      );
    }
    if (speedKph >= 35 && speedKph <= 40) {
      return const DriveFact(
        title: 'PASSSTRASSEN-TIPP',
        message: 'Gang 2 trifft bei 35 km/h das Maximum von 6.300 N Zugkraft.',
      );
    }
    if (gear == 6 && speedKph >= 105 && speedKph <= 115) {
      return const DriveFact(
        title: 'WOHNMOBIL-SWEET-SPOT',
        message:
            'Um 109 km/h trifft maximales Drehmoment auf effizientes Cruisen.',
      );
    }
    return null;
  }
}
