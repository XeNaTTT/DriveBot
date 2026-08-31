import 'package:driveassistant_ar/features/drive_assistant/domain/shift_advisor.dart';
import 'package:driveassistant_ar/features/drive_assistant/domain/drive_telemetry.dart';
import 'package:driveassistant_ar/features/drive_assistant/domain/vehicle_shift_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const advisor = ShiftAdvisor(VehicleShiftProfile.citroenJumper2020);

  test('selects first gear and idle rpm while stopped', () {
    final result = advisor.recommend(0);
    expect(result.gear, 1);
    expect(result.rpm, 800);
  });

  test('selects a high gear in the efficient range at cruising speed', () {
    final result = advisor.recommend(84);
    expect(result.gear, 6);
    expect(result.rpm, inInclusiveRange(1700, 2200));
  });

  test('recommended rpm follows GPS speed', () {
    expect(advisor.recommend(80).rpm, lessThan(advisor.recommend(100).rpm));
  });

  group('drive telemetry', () {
    const calculator = DriveTelemetryCalculator(
      VehicleShiftProfile.citroenJumper2020,
    );

    test('uses the configured drivetrain formula for engine speed', () {
      final telemetry = calculator.calculate(speedKph: 100, gear: 6);

      expect(telemetry.rpm, 2119);
      expect(telemetry.zone, EfficiencyZone.optimal);
    });

    test('interpolates the active tractive-force curve', () {
      final telemetry = calculator.calculate(speedKph: 102, gear: 5);

      expect(telemetry.tractiveForceNewton, 2150);
    });

    test('shows the pass-road fact in the hairpin speed window', () {
      final telemetry = calculator.calculate(speedKph: 37, gear: 2);

      expect(telemetry.fact?.title, 'PASSSTRASSEN-TIPP');
    });

    test('shows cruising context for sixth gear', () {
      final telemetry = calculator.calculate(speedKph: 109, gear: 6);

      expect(telemetry.fact?.title, 'WOHNMOBIL-SWEET-SPOT');
    });
  });
}
