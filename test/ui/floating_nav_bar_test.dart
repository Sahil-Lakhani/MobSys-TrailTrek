import 'package:claimtrek/ui/common/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _tabs = [
  NavDestination(
    icon: Icons.map_outlined,
    selectedIcon: Icons.map,
    label: 'Map',
  ),
  NavDestination(
    icon: Icons.star_outline,
    selectedIcon: Icons.star,
    label: 'Board',
  ),
  NavDestination(
    icon: Icons.list_outlined,
    selectedIcon: Icons.list,
    label: 'Runs',
  ),
];

void main() {
  Future<void> pump(
    WidgetTester tester,
    int index,
    ValueChanged<int> onSelected,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FloatingNavBar(
            destinations: _tabs,
            currentIndex: index,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('every tab is labelled and tappable', (tester) async {
    int? tapped;
    await pump(tester, 0, (i) => tapped = i);

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Board'), findsOneWidget);
    expect(find.text('Runs'), findsOneWidget);

    await tester.tap(find.text('Runs'));
    expect(tapped, 2);
  });

  testWidgets('the indicator springs over to the new tab and settles there', (
    tester,
  ) async {
    await pump(tester, 0, (_) {});
    await pump(tester, 2, (_) {});
    // A spring never settles on a fixed duration, so let it run out rather than guessing.
    await tester.pumpAndSettle();

    final runs = tester.getCenter(find.text('Runs'));
    final indicator = tester.getRect(
      find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_Indicator',
        ),
      ),
    );
    expect(indicator.center.dx, closeTo(runs.dx, 1));
  });
}
