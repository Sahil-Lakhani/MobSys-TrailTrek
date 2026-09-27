library;

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

class ClaimPreview {
  final double stolenAreaM2;
  final int stolenFromCount;

  const ClaimPreview({
    required this.stolenAreaM2,
    required this.stolenFromCount,
  });
}
