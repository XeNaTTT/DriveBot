import 'package:driveassistant_ar/features/ar_racing/domain/race_session.dart';
import 'package:driveassistant_ar/features/ar_racing/presentation/ar_racing_screen.dart';
import 'package:driveassistant_ar/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collision adds damage and reduces speed', () {
    const session = RaceSession(speedKmh: 80);
    final collided = session.collide(impact: .75);
    expect(collided.damage, 18);
    expect(collided.speedKmh, lessThan(session.speedKmh));
  });

  test('acceleration advances the vehicle into the room perspective', () {
    const session = RaceSession(speedKmh: 34);
    final advanced = session.accelerate();

    expect(advanced.runProgress, .12);
    expect(advanced.perspectiveScale, lessThan(session.perspectiveScale));
  });

  test('steering changes lateral position while driving', () {
    final driven = const RaceSession(
      speedKmh: 40,
    ).steer(1).drive(elapsedSeconds: 1, accelerating: true, braking: false);

    expect(driven.lateralPosition, greaterThan(0));
    expect(driven.speedKmh, greaterThan(40));
  });

  test('brake reduces speed', () {
    final stopped = const RaceSession(
      speedKmh: 50,
    ).drive(elapsedSeconds: .5, accelerating: false, braking: true);

    expect(stopped.speedKmh, lessThan(50));
  });

  testWidgets('three caravans can be selected and race can start', (
    tester,
  ) async {
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
    expect(find.text('WOHNWAGEN'), findsOneWidget);
    expect(find.byKey(const Key('caravan-comet')), findsOneWidget);
    expect(find.byKey(const Key('caravan-terra')), findsOneWidget);
    expect(find.byKey(const Key('caravan-neon')), findsOneWidget);

    await tester.tap(find.byKey(const Key('caravan-terra')));
    await tester.pumpAndSettle();
    expect(find.text('TERRA X'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-ar-race')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ar-race-view')), findsOneWidget);
    expect(find.byKey(const Key('injected-ar-camera')), findsOneWidget);
    expect(find.byKey(const Key('racing-caravan-3d')), findsOneWidget);
    expect(find.byKey(const Key('fleeing-caravan')), findsOneWidget);
    expect(find.byKey(const Key('brake-pedal')), findsOneWidget);
    expect(find.byKey(const Key('gas-pedal')), findsOneWidget);

    await tester.tap(find.byKey(const Key('simulate-impact')));
    await tester.pump();
    expect(find.text('SCHADEN  19%'), findsOneWidget);
  });
}
