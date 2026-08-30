import 'package:driveassistant_ar/features/drive_assistant/domain/shift_advisor.dart';
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
    expect(result.rpm, inInclusiveRange(1400, 2000));
  });

  test('recommended rpm follows GPS speed', () {
    expect(advisor.recommend(80).rpm, lessThan(advisor.recommend(100).rpm));
  });
}
