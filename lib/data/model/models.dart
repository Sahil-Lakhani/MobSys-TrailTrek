/// Domain types that are not table rows.
///
/// Drift already generates immutable row classes (`Territory`, `Run`, `Trail`) from the table
/// definitions, and those are used directly rather than being copied into a parallel set of
/// models.
library;

/// One row of the leaderboard: a player and everything they hold.
///
/// [rank] is part of the row rather than derived from list position, so a player who keeps
/// their area but moves down the table still renders the new rank.
class LeaderboardEntry {
  final int rank;
  final String ownerId;
  final String ownerName;
  final String colorHex;
  final double totalAreaM2;
  final int territoryCount;
  final bool isYou;

  const LeaderboardEntry({
    required this.rank,
    required this.ownerId,
    required this.ownerName,
    required this.colorHex,
    required this.totalAreaM2,
    required this.territoryCount,
    required this.isYou,
  });

  LeaderboardEntry withRank(int value) => LeaderboardEntry(
    rank: value,
    ownerId: ownerId,
    ownerName: ownerName,
    colorHex: colorHex,
    totalAreaM2: totalAreaM2,
    territoryCount: territoryCount,
    isYou: isYou,
  );
}

/// What a committed claim did to the world.
class ClaimOutcome {
  final String territoryId;
  final double areaM2;
  final double stolenAreaM2;
  final int stolenFromCount;

  const ClaimOutcome({
    required this.territoryId,
    required this.areaM2,
    required this.stolenAreaM2,
    required this.stolenFromCount,
  });
}

/// What a claim *would* do, computed without writing anything.
///
/// The summary screen needs these numbers before the runner has decided to keep the run, and a
/// discarded run must leave the world exactly as it found it.
class ClaimPreview {
  final double stolenAreaM2;
  final int stolenFromCount;

  const ClaimPreview({
    required this.stolenAreaM2,
    required this.stolenFromCount,
  });
}
