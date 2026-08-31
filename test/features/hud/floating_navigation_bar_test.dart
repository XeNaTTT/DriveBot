import 'package:driveassistant_ar/features/hud/presentation/floating_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('development bar exposes selection semantics and callbacks', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: FloatingNavigationBar(
            items: const [
              FloatingNavigationItem(
                id: 'hud',
                label: 'HUD',
                systemImage: 'viewfinder',
              ),
              FloatingNavigationItem(
                id: 'assistant',
                label: 'Fahrassistenz',
                systemImage: 'speedometer',
              ),
            ],
            selectedId: 'hud',
            onSelected: (id) => selected = id,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('HUD'), findsWidgets);
    expect(find.bySemanticsLabel('Fahrassistenz'), findsWidgets);
    await tester.tap(find.byKey(const Key('floating-navigation-assistant')));
    expect(selected, 'assistant');
  });
}
