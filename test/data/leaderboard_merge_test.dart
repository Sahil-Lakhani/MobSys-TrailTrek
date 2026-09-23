import 'package:claimtrek/data/leaderboard_merge.dart';
import 'package:claimtrek/data/model/models.dart';
import 'package:test/test.dart';

LeaderboardEntry entry(
  String ownerId,
  String name,
  double area, {
  bool isYou = false,
  int count = 1,
}) => LeaderboardEntry(
  rank: 0,
  ownerId: ownerId,
  ownerName: name,
  colorHex: '#FF6B35',
  totalAreaM2: area,
  territoryCount: count,
  isYou: isYou,
);

void main() {
  test('real players and local rivals appear on one board', () {
    final local = [entry('rival-1', 'Jonas', 75600)];
    final remote = [entry('uid-a', 'Sahil', 106200)];

    final merged = mergeLeaderboards(local: local, remote: remote, myId: 'uid-a');

    expect(merged.map((e) => e.ownerName), containsAll(['Jonas', 'Sahil']));
    expect(merged, hasLength(2));
  });

  test('the board is ranked by area, largest first', () {
    final merged = mergeLeaderboards(
      local: [entry('rival-1', 'Jonas', 40000), entry('rival-2', 'Mira', 90000)],
      remote: [entry('uid-a', 'Sahil', 60000)],
      myId: 'uid-a',
    );

    expect(merged.map((e) => e.ownerName), ['Mira', 'Sahil', 'Jonas']);
    // Rank is carried on the row rather than inferred from position, so it has to be restated
    // after a merge or the board renumbers itself wrongly.
    expect(merged.map((e) => e.rank), [1, 2, 3]);
  });

  test('a player present in both sources is listed once', () {
    // The signed-in player is in the local table (their own claims) and in Firestore (their
    // published standing). Counting both would double their holding and put them top of a
    // board they have not earned.
    final merged = mergeLeaderboards(
      local: [entry('uid-a', 'Sahil', 106200, isYou: true)],
      remote: [entry('uid-a', 'Sahil', 106200)],
      myId: 'uid-a',
    );

    expect(merged, hasLength(1));
    expect(merged.single.totalAreaM2, closeTo(106200, 1e-9));
  });

  test('the local figure wins for the signed-in player', () {
    // Local is computed from the territory geometry that is actually on this device; the
    // remote total is a mirror that may lag a write.
    final merged = mergeLeaderboards(
      local: [entry('uid-a', 'Sahil', 106200, isYou: true)],
      remote: [entry('uid-a', 'Sahil', 5000)],
      myId: 'uid-a',
    );

    expect(merged.single.totalAreaM2, closeTo(106200, 1e-9));
    expect(merged.single.isYou, isTrue);
  });

  test('you are marked as you even when only the remote row exists', () {
    // Signing in on a second device: Firestore knows the standing, this device holds no ground.
    final merged = mergeLeaderboards(
      local: const [],
      remote: [entry('uid-a', 'Sahil', 106200)],
      myId: 'uid-a',
    );

    expect(merged.single.isYou, isTrue);
  });

  test('signed out, the board is simply the local one', () {
    final merged = mergeLeaderboards(
      local: [entry('local-1', 'You', 1000, isYou: true), entry('rival-1', 'Jonas', 900)],
      remote: const [],
      myId: 'local-1',
    );

    expect(merged.map((e) => e.ownerName), ['You', 'Jonas']);
    expect(merged.first.isYou, isTrue);
  });

  test('players holding nothing are left off the board', () {
    // A signed-in account that has never closed a loop has no standing to show.
    final merged = mergeLeaderboards(
      local: const [],
      remote: [entry('uid-a', 'Sahil', 0), entry('uid-b', 'Ravi', 5000)],
      myId: 'uid-a',
    );

    expect(merged.map((e) => e.ownerName), ['Ravi']);
  });
}
