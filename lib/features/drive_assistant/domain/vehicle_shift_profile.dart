class VehicleShiftProfile {
  const VehicleShiftProfile({
    required this.name,
    required this.gearRatios,
    required this.finalDriveRatio,
    required this.wheelCircumferenceMeters,
    required this.idleRpm,
    required this.ecoRpmStart,
    required this.ecoRpmEnd,
    required this.powerRpmStart,
    required this.powerRpmEnd,
    required this.maximumRpm,
    required this.tractiveForceCurves,
  });

  final String name;
  final List<double> gearRatios;
  final double finalDriveRatio;
  final double wheelCircumferenceMeters;
  final int idleRpm;
  final int ecoRpmStart;
  final int ecoRpmEnd;
  final int powerRpmStart;
  final int powerRpmEnd;
  final int maximumRpm;
  final Map<int, List<TractiveForcePoint>> tractiveForceCurves;

  double speedKphAtRpm({required int rpm, required int gear}) {
    final safeGear = gear.clamp(1, gearRatios.length);
    return rpm *
        60 *
        wheelCircumferenceMeters /
        (gearRatios[safeGear - 1] * finalDriveRatio * 1000);
  }

  static const citroenJumper2020 = VehicleShiftProfile(
    name: 'Citroën Jumper · 2020',
    gearRatios: [3.727, 1.952, 1.290, 0.875, 0.673, 0.585],
    finalDriveRatio: 4.933,
    wheelCircumferenceMeters: 2.27,
    idleRpm: 800,
    ecoRpmStart: 1800,
    ecoRpmEnd: 2200,
    powerRpmStart: 1750,
    powerRpmEnd: 2500,
    maximumRpm: 4200,
    tractiveForceCurves: {
      1: [
        TractiveForcePoint(10, 6500),
        TractiveForcePoint(17, 12000),
        TractiveForcePoint(24, 12000),
        TractiveForcePoint(36, 8900),
        TractiveForcePoint(41, 6000),
      ],
      2: [
        TractiveForcePoint(19, 3400),
        TractiveForcePoint(33, 6300),
        TractiveForcePoint(47, 6300),
        TractiveForcePoint(70, 4600),
        TractiveForcePoint(79, 3100),
      ],
      3: [
        TractiveForcePoint(28, 2200),
        TractiveForcePoint(49, 4150),
        TractiveForcePoint(70, 4150),
        TractiveForcePoint(106, 3050),
        TractiveForcePoint(118, 2100),
      ],
      4: [
        TractiveForcePoint(42, 1500),
        TractiveForcePoint(73, 2800),
        TractiveForcePoint(104, 2800),
        TractiveForcePoint(156, 2050),
      ],
      5: [
        TractiveForcePoint(54, 1150),
        TractiveForcePoint(95, 2150),
        TractiveForcePoint(135, 2150),
        TractiveForcePoint(203, 1600),
      ],
      6: [
        TractiveForcePoint(62, 1000),
        TractiveForcePoint(109, 1880),
        TractiveForcePoint(137, 1880),
        TractiveForcePoint(156, 1880),
        TractiveForcePoint(218, 1400),
      ],
    },
  );
}

class TractiveForcePoint {
  const TractiveForcePoint(this.speedKph, this.forceNewton);

  final double speedKph;
  final double forceNewton;
}
