import 'package:driveassistant_ar/features/ar/domain/ar_projection_mapper.dart';
import 'package:driveassistant_ar/features/hud/domain/hud_warning_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = ArProjectionMapper(horizontalFovDegrees: 60);

  test('object outside FOV is hidden', () {
    final markers =
        mapper.project(warnings: [_warning(95)], userHeadingDegrees: 0);
    expect(markers, isEmpty);
  });

  test('object inside FOV is visible', () {
    final markers =
        mapper.project(warnings: [_warning(20)], userHeadingDegrees: 0);
    expect(markers, hasLength(1));
  });

  test('maps left center right x positions', () {
    final markers = mapper.project(
      warnings: [_warning(330), _warning(0), _warning(30)],
      userHeadingDegrees: 0,
    );
    expect(markers[0].normalizedX, closeTo(0, 0.01));
    expect(markers[1].normalizedX, closeTo(0.5, 0.01));
    expect(markers[2].normalizedX, closeTo(1, 0.01));
  });
}

HudWarningItem _warning(int bearing) => HudWarningItem(
      type: WarningType.speedCamera,
      title: 'A3 Suben',
      detail: 'Keep distance',
      distanceMeters: 1200,
      bearingDegrees: bearing,
      severity: 3,
    );
