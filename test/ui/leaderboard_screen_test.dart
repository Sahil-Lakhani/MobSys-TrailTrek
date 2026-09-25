import 'package:claimtrek/data/model/models.dart';
import 'package:claimtrek/data/providers.dart';
import 'package:claimtrek/ui/board/leaderboard_screen.dart';
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
  Future<void> pump(WidgetTester tester, AsyncValue<List<LeaderboardEntry>> board) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaderboardProvider.overrideWith(
            (ref) => board.when(
              data: Stream<List<LeaderboardEntry>>.value,
              error: (e, s) => Stream<List<LeaderboardEntry>>.error(e),
              loading: () => const Stream<List<LeaderboardEntry>>.empty(),
            ),
          ),
        ],
        child: const MaterialApp(home: LeaderboardScreen()),
      ),
    );
  }

  group('formatArea', () {
    test('reads as hectares once the numbers get big', () {
      // 10.62 ha is legible; 106 200 m² is not, and the whole point of the board is a glance.
      expect(formatArea(106200), '10.62 ha');
    });

    test('stays in square metres below a hectare', () {
      expect(formatArea(5000), '5000 m²');
    });
  });

  testWidgets('ranks every holder and marks which one is you', (tester) async {
    await pump(
      tester,
      AsyncValue.data([
        entry(1, 'Mara', 42000),
        entry(2, 'You', 10600, isYou: true),
        entry(3, 'Vik', 1800),
      ]),
    );
    await tester.pump();

    expect(find.text('Mara'), findsOneWidget);
    expect(find.text('You (you)'), findsOneWidget);
    expect(find.text('4.20 ha'), findsOneWidget);
    expect(find.text('1.06 ha'), findsOneWidget);
  });

  testWidgets('your own standing leads the board', (tester) async {
    // Your rank is the one number you open the tab for, so it sits above the list.
    await pump(
      tester,
      AsyncValue.data([
        entry(1, 'Mara', 42000),
        entry(2, 'You', 10600, isYou: true),
      ]),
    );
    await tester.pump();

    expect(find.text('#2 · 1.06 ha'), findsOneWidget);
  });

  testWidgets('an empty board explains itself rather than showing blank', (
    tester,
  ) async {
    await pump(tester, const AsyncValue.data([]));
    await tester.pump();

    expect(
      find.text('No ground claimed yet. Run a loop and it lands here.'),
      findsOneWidget,
    );
  });

  testWidgets('plots are pluralised', (tester) async {
    await pump(
      tester,
      AsyncValue.data([entry(1, 'Mara', 42000, plots: 1)]),
    );
    await tester.pump();

    expect(find.text('1 plot'), findsOneWidget);
  });
}
