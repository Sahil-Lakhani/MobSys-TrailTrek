import 'package:claimtrek/ui/home/leaderboard_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

// A typical phone in logical pixels.
const double screen = 920;

void main() {
  test('collapsed, the board shows more than a single player', () {
    // One visible row reads as "there is one player", which is wrong and looks broken.
    final collapsed = LeaderboardMetrics.collapsedFraction(screen);
    final visibleRows =
        (collapsed * screen - LeaderboardMetrics.headerHeight) /
        LeaderboardMetrics.rowHeight;

    expect(visibleRows, greaterThanOrEqualTo(2));
  });

  test('a short board does not expand into a field of white', () {
    // Two players should not open a sheet sized for ten.
    final two = LeaderboardMetrics.expandedFraction(rows: 2, screenHeight: screen);

    expect(two, lessThan(0.35));
  });

  test('a long board is capped rather than swallowing the map', () {
    final many = LeaderboardMetrics.expandedFraction(rows: 40, screenHeight: screen);

    expect(many, LeaderboardMetrics.maxFraction);
  });

  test('more players always means at least as much room', () {
    var previous = 0.0;
    for (var rows = 0; rows <= 20; rows++) {
      final fraction = LeaderboardMetrics.expandedFraction(
        rows: rows,
        screenHeight: screen,
      );
      expect(fraction, greaterThanOrEqualTo(previous));
      previous = fraction;
    }
  });

  test('expanded always leaves room to drag open from collapsed', () {
    // DraggableScrollableSheet requires max > min; an empty board must not invert them.
    for (final rows in [0, 1, 2, 3, 10]) {
      final collapsed = LeaderboardMetrics.collapsedFraction(screen);
      final expanded = LeaderboardMetrics.expandedFraction(
        rows: rows,
        screenHeight: screen,
      );
      expect(expanded, greaterThan(collapsed), reason: '$rows rows');
    }
  });

  test('a tiny screen still yields a usable sheet', () {
    // A short window must not produce a fraction above 1.0, which would throw.
    final fraction = LeaderboardMetrics.expandedFraction(
      rows: 30,
      screenHeight: 320,
    );
    expect(fraction, lessThanOrEqualTo(LeaderboardMetrics.maxFraction));
    expect(LeaderboardMetrics.collapsedFraction(320), lessThan(fraction));
  });
}
