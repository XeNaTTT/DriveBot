import 'package:driveassistant_ar/features/data_sources/data/mock_data_source_registry.dart';
import 'package:driveassistant_ar/features/hud/data/mock_hud_repository.dart';
import 'package:driveassistant_ar/features/hud/presentation/hud_screen.dart';
import 'package:driveassistant_ar/features/location/data/mock_location_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders hud mock cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HudScreen(
          hudRepository: MockHudRepository(),
          locationRepository: MockLocationRepository(),
          dataSourceRegistry: MockDataSourceRegistry(),
        ),
      ),
    );

    expect(find.text('DriveAssistant AR'), findsOneWidget);
    expect(find.text('Speed Camera Ahead'), findsOneWidget);
    expect(find.text('Speed Limit 80 km/h'), findsOneWidget);
    expect(find.text('Roadwork Zone'), findsOneWidget);
    expect(find.text('Weather Warning'), findsOneWidget);
    expect(find.text('Charging Station Nearby'), findsOneWidget);
  });
}
