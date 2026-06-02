import 'package:driveassistant_ar/features/ar/domain/ar_vertical_placement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('horizonY changes when pitch changes', () {
    final model = const ArVerticalPlacement().horizonModel;
    final level = model.horizonY(screenHeight: 800, devicePitchDegrees: 0);
    final tilted = model.horizonY(screenHeight: 800, devicePitchDegrees: 10);
    expect(tilted, greaterThan(level));
  });

  test('marker y is clamped inside SafeArea', () {
    final model = const ArVerticalPlacement().horizonModel;
    final y = model.horizonY(
      screenHeight: 800,
      safeAreaTop: 60,
      safeAreaBottom: 40,
      devicePitchDegrees: 90,
    );
    expect(y, inInclusiveRange(160, 504));
  });
}
