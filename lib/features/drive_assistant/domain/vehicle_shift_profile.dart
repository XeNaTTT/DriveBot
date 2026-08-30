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

  static const citroenJumper2020 = VehicleShiftProfile(
    name: 'Citroën Jumper · 2020',
    gearRatios: [3.73, 1.95, 1.29, 0.88, 0.67, 0.56],
    finalDriveRatio: 4.93,
    wheelCircumferenceMeters: 2.25,
    idleRpm: 800,
    ecoRpmStart: 1400,
    ecoRpmEnd: 2000,
    powerRpmStart: 2000,
    powerRpmEnd: 3500,
    maximumRpm: 4500,
  );
}
