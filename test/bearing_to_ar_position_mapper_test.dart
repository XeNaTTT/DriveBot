import 'package:driveassistant_ar/features/hud/domain/bearing_to_ar_position_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = BearingToArPositionMapper(
    maxRenderableDistanceMeters: 1500,
    horizontalFieldOfViewDegrees: 80,
  );

  test('maps heading-aligned warning to center', () {
    final position = mapper.map(
      userHeadingDegrees: 90,
      warningBearingDegrees: 90,
      warningDistanceMeters: 300,
    );

    expect(position.horizontalAlignment, 0);
    expect(position.normalizedDistance, closeTo(0.2, 0.001));
  });

  test('normalizes angle around north boundary', () {
    final position = mapper.map(
      userHeadingDegrees: 350,
      warningBearingDegrees: 10,
      warningDistanceMeters: 100,
    );

    expect(position.horizontalAlignment, closeTo(0.5, 0.001));
  });

  test('clamps off-axis warnings to screen edge', () {
    final position = mapper.map(
      userHeadingDegrees: 0,
      warningBearingDegrees: 160,
      warningDistanceMeters: 100,
    );

    expect(position.horizontalAlignment, 1);
  });

  test('clamps far warnings for stable readability', () {
    final position = mapper.map(
      userHeadingDegrees: 0,
      warningBearingDegrees: 0,
      warningDistanceMeters: 5000,
    );

    expect(position.normalizedDistance, 1);
    expect(position.verticalBias, 0.2);
  });
}
