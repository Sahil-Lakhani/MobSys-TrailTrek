import 'model/models.dart';

List<LeaderboardEntry> mergeLeaderboards({
  required List<LeaderboardEntry> local,
  required List<LeaderboardEntry> remote,
  required String myId,
}) {
  final byOwner = <String, LeaderboardEntry>{};

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
          .where((e) => e.totalAreaM2 > 0)
          .map(
            (e) => e.ownerId == myId && !e.isYou
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

  return [for (var i = 0; i < entries.length; i++) entries[i].withRank(i + 1)];
}
