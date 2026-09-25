import 'package:claimtrek/data/model/models.dart';
import 'package:claimtrek/data/providers.dart';
import 'package:claimtrek/ui/leaderboard/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LeaderboardEntry entry(
  int rank,
  String name,
  double areaM2, {
  bool isYou = false,
  int plots = 1,
}) => LeaderboardEntry(
  rank: rank,
  ownerId: name,
  ownerName: name,
  colorHex: '#2E86DE',
  totalAreaM2: areaM2,
  territoryCount: plots,
  isYou: isYou,
);

void main() {
  Future<void> pump(WidgetTester tester, List<LeaderboardEntry> board) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaderboardProvider.overrideWith(
            (ref) => Stream<List<LeaderboardEntry>>.value(board),
          ),
        ],
        child: const MaterialApp(home: LeaderboardScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('ranks every holder and marks which one is you', (tester) async {
    await pump(tester, [
      entry(1, 'Mara', 42000),
      entry(2, 'You', 10600, isYou: true),
      entry(3, 'Vik', 1800),
    ]);

    expect(find.text('Mara'), findsOneWidget);
    expect(find.text('You (you)'), findsOneWidget);
    expect(find.text('4.20 ha'), findsOneWidget);
    expect(find.text('1800 m²'), findsOneWidget);
  });

  testWidgets('your own standing is pinned above the table', (tester) async {
    await pump(tester, [
      entry(1, 'Mara', 42000),
      entry(2, 'You', 10600, isYou: true),
    ]);

    expect(find.text('#2 · 1.06 ha'), findsOneWidget);
  });

  testWidgets('an empty board explains itself rather than showing blank', (
    tester,
  ) async {
    await pump(tester, const []);

    expect(
      find.text('No ground claimed yet. Run a loop and it lands here.'),
      findsOneWidget,
    );
  });

  testWidgets('plots are pluralised', (tester) async {
    await pump(tester, [entry(1, 'Mara', 42000, plots: 1), entry(2, 'Vik', 900, plots: 3)]);

    expect(find.text('1 plot'), findsOneWidget);
    expect(find.text('3 plots'), findsOneWidget);
  });
}
