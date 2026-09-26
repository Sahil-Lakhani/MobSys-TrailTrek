import 'model/models.dart';

/// Folds the local board and the Firestore board into one ranking.
///
/// Two sources exist because they answer different questions. The local table holds the ground
/// on this device — the player's own claims, plus the stand-in rivals that keep a solo game
/// worth playing. Firestore holds what other real accounts have published. Neither is complete
/// on its own.
///
/// Pure, so the rule can be tested without a database or a network.
List<LeaderboardEntry> mergeLeaderboards({
  required List<LeaderboardEntry> local,
  required List<LeaderboardEntry> remote,
  required String myId,
}) {
  final byOwner = <String, LeaderboardEntry>{};

  // Your own figure comes from here: it is computed from the ground actually on this device,
  // whereas your published total is a mirror that can lag the write that produced it.
  //
  // Everyone else's comes from their published standing when there is one. This device only
  // holds the rival ground near where it has been, so its sum of a rival's plots is a partial
  // count; the standing they published covers everything they hold.
  for (final e in local) {
    byOwner[e.ownerId] = e;
  }
  for (final e in remote) {
    if (e.ownerId == myId) {
      byOwner.putIfAbsent(e.ownerId, () => e);
    } else {
      byOwner[e.ownerId] = e;
    }
  }

  final entries =
      byOwner.values
          // A signed-in account that has never closed a loop has no standing to show.
          .where((e) => e.totalAreaM2 > 0)
          .map(
            (e) => e.ownerId == myId && !e.isYou
                // Arrives when the player holds ground on another device but none on this one.
                ? LeaderboardEntry(
                    rank: e.rank,
                    ownerId: e.ownerId,
                    ownerName: e.ownerName,
                    colorHex: e.colorHex,
                    totalAreaM2: e.totalAreaM2,
                    territoryCount: e.territoryCount,
                    isYou: true,
                  )
                : e,
          )
          .toList()
        ..sort((a, b) => b.totalAreaM2.compareTo(a.totalAreaM2));

  // Rank lives on the row rather than being read off the list position, so it has to be
  // restated here or the merged board renumbers itself from the pre-merge ordering.
  return [for (var i = 0; i < entries.length; i++) entries[i].withRank(i + 1)];
}
