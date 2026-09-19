import 'package:driveassistant_ar/features/ar_racing/presentation/ar_racing_screen.dart';
import 'package:driveassistant_ar/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'garage opens the native race surface without simulated controls',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ArRacingScreen(
            backgroundBuilder: (_) => const ColoredBox(
              key: Key('injected-ar-camera'),
              color: Colors.black,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('ar-racing-garage')), findsOneWidget);
      await tester.tap(find.byKey(const Key('start-ar-race')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ar-race-view')), findsOneWidget);
      expect(find.byKey(const Key('injected-ar-camera')), findsOneWidget);
      expect(find.byKey(const Key('simulate-impact')), findsNothing);
      expect(find.text('SCHADEN'), findsNothing);
      expect(find.byKey(const Key('close-ar-race')), findsOneWidget);
    },
  );
}
