import 'package:driveassistant_ar/features/ar_racing/presentation/ar_racing_screen.dart';
import 'package:driveassistant_ar/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('swiping the showroom changes the selected race vehicle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const ArRacingScreen()),
    );
    final hero = find.byKey(const Key('static-showroom-art'));
    final original = tester.element(hero);
    final bounds = tester.getRect(hero);
    expect(bounds, tester.getRect(find.byType(Scaffold)));
    await tester.tap(find.byKey(const Key('caravan-compact')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('compact')),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('FAMILY CRUISER'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('sport')),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('URBAN CAMPER'), findsOneWidget);
    expect(tester.element(hero), same(original));
    expect(tester.getRect(hero), bounds);
  });
  testWidgets(
    'landscape garage shows every vehicle and start without scrolling',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(568, 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const ArRacingScreen()),
      );

      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, 0);
      final choices = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith('caravan-'),
      );
      expect(choices.hitTestable(), findsNWidgets(3));
      expect(
        find.byKey(const Key('start-ar-race')).hitTestable(),
        findsOneWidget,
      );
      for (final entry in const {
        'compact': 'URBAN CAMPER',
        'sport': 'FAMILY CRUISER',
        'offroad': 'EXPEDITION BEAST',
      }.entries) {
        await tester.tap(find.byKey(Key('caravan-${entry.key}')));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(scroll.position.maxScrollExtent, 0);
      }
      expect(tester.takeException(), isNull);
    },
  );

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
