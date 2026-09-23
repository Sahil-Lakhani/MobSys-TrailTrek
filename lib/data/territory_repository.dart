import 'dart:math' as math;

import 'package:clipper2/clipper2.dart';
import 'package:uuid/uuid.dart';

import '../geo/lat_lng.dart';
import '../geo/projection.dart';
import '../geo/territory_engine.dart';
import 'local/database.dart';
import 'local/elevation_codec.dart';
import 'local/path_codec.dart';
import 'model/models.dart';
import 'player_identity.dart';

/// The UI talks to this; it never touches a DAO or a network client directly.
///
/// Rivals live in the local database and are seeded once around wherever the first run starts.
/// When a backend lands it writes through the same methods — the UI does not learn a new shape.
class TerritoryRepository {
  /// Positional rather than named because Dart forbids private *named* parameters, and these
  /// fields should stay private.
  TerritoryRepository(this._db, this._player, [this._uuid = const Uuid()]);

  final ClaimTrekDatabase _db;
  final PlayerIdentity _player;
  final Uuid _uuid;

  /// Below this a difference is float noise from re-projection, not ground that changed hands.
  static const double _meaningfulLossM2 = 1.0;

  TerritoryDao get _territories => _db.territoryDao;
  RunDao get _runs => _db.runDao;

  // ------------------------------------------------------------------ observation

  Stream<List<Territory>> watchTerritories() => _territories.watchAll();

  Stream<List<Run>> watchRuns() => _runs.watchAll();

  /// Unverified ground is held and drawn, but does not score.
  Stream<List<LeaderboardEntry>> watchLeaderboard() =>
      _territories.watchAll().map(_toLeaderboard);

  List<LeaderboardEntry> _toLeaderboard(List<Territory> rows) {
    final byOwner = <String, List<Territory>>{};
    for (final row in rows.where((r) => r.verified)) {
      byOwner.putIfAbsent(row.ownerId, () => []).add(row);
    }

    final entries =
        byOwner.entries.map((e) {
          final owned = e.value;
          return LeaderboardEntry(
            rank: 0,
            ownerId: e.key,
            ownerName: owned.first.ownerName,
            colorHex: owned.first.colorHex,
            totalAreaM2: owned.fold(0.0, (sum, t) => sum + t.areaM2),
            territoryCount: owned.length,
            isYou: e.key == _player.id,
          );
        }).toList()
          ..sort((a, b) => b.totalAreaM2.compareTo(a.totalAreaM2));

    return [
      for (var i = 0; i < entries.length; i++) entries[i].withRank(i + 1),
    ];
  }

  // ----------------------------------------------------------------------- claims

  Future<List<Claim>> _rivalClaims() async {
    final rows = await _territories.getAll();
    return _toClaims(rows.where((r) => r.ownerId != _player.id));
  }

  List<Claim> _toClaims(Iterable<Territory> rows) {
    final out = <Claim>[];
    for (final row in rows) {
      final geometry = TerritoryEngine.fromWkt(row.wkt);
      // A row whose WKT will not parse is corrupt. Skipping it keeps one bad row from
      // destroying an otherwise valid claim resolution.
      if (geometry == null || geometry.isEmpty) continue;
      out.add(
        Claim(
          id: row.id,
          ownerId: row.ownerId,
          geometry: geometry,
          areaM2: row.areaM2,
        ),
      );
    }
    return out;
  }

  /// What this claim *would* take, without writing anything.
  Future<ClaimPreview> previewClaim(PathsD claimGeographic) async {
    final rivals = await _rivalClaims();
    final losses = _losses(rivals, TerritoryEngine.resolveClaim(claimGeographic, rivals));
    return ClaimPreview(
      stolenAreaM2: losses.area,
      stolenFromCount: losses.count,
    );
  }

  ({double area, int count}) _losses(
    List<Claim> before,
    List<Claim> after,
  ) {
    final survivors = {for (final c in after) c.id: c};
    var area = 0.0;
    var count = 0;
    for (final original in before) {
      final survivor = survivors[original.id];
      final lost = survivor == null
          ? original.areaM2
          : original.areaM2 - survivor.areaM2;
      if (lost > _meaningfulLossM2) {
        area += lost;
        count++;
      }
    }
    return (area: area, count: count);
  }

  /// Commit a freshly closed loop.
  ///
  /// Order matters: rival territories are clipped against the new claim *first*, then the claim
  /// is merged with whatever the same runner already held. Reversed, a runner would steal from
  /// themselves and lose the overlap to the sliver filter.
  Future<ClaimOutcome> commitClaim({
    required PathsD claimGeographic,
    required LatLng reference,
    required bool verified,
  }) async {
    final all = await _territories.getAll();
    final ownerId = _player.id;

    final rivalRows = all.where((r) => r.ownerId != ownerId).toList();
    final ownRows = all.where((r) => r.ownerId == ownerId).toList();

    final rivals = _toClaims(rivalRows);
    final survivors = TerritoryEngine.resolveClaim(claimGeographic, rivals);
    final survivorsById = {for (final c in survivors) c.id: c};
    final losses = _losses(rivals, survivors);

    // Clipped rivals are written back; the ones reduced to slivers are removed outright.
    final updates = <Territory>[];
    for (final survivor in survivors) {
      final original = rivals.firstWhere((c) => c.id == survivor.id);
      if (original.areaM2 <= survivor.areaM2 + _meaningfulLossM2) continue;
      final row = rivalRows.firstWhere((r) => r.id == survivor.id);
      updates.add(
        row.copyWith(
          wkt: TerritoryEngine.toWkt(survivor.geometry),
          areaM2: survivor.areaM2,
        ),
      );
    }
    if (updates.isNotEmpty) await _territories.upsertAll(updates);

    final wipedOut = rivals
        .where((c) => !survivorsById.containsKey(c.id))
        .map((c) => c.id)
        .toList();
    if (wipedOut.isNotEmpty) await _territories.deleteByIds(wipedOut);

    // Fold into the runner's own ground so one player reads as one holding.
    final merged = TerritoryEngine.mergeOwn(claimGeographic, _toClaims(ownRows));
    if (ownRows.isNotEmpty) {
      await _territories.deleteByIds(ownRows.map((r) => r.id).toList());
    }

    final id = _uuid.v4();
    final area = TerritoryEngine.areaM2(merged);
    await _territories.upsert(
      Territory(
        id: id,
        ownerId: ownerId,
        ownerName: _player.name,
        colorHex: _player.colorHex,
        wkt: TerritoryEngine.toWkt(merged),
        areaM2: area,
        geohash5: Projection.geohash5(reference),
        refLat: reference.latitude,
        refLng: reference.longitude,
        claimedAt: DateTime.now().millisecondsSinceEpoch,
        verified: verified,
      ),
    );

    return ClaimOutcome(
      territoryId: id,
      areaM2: area,
      stolenAreaM2: losses.area,
      stolenFromCount: losses.count,
    );
  }

  // ------------------------------------------------------------------- signing in

  /// Moves ground claimed under a previous owner id onto the current identity.
  ///
  /// Called once when a player signs in: everything they captured anonymously is filed under a
  /// local id that nothing will ever answer to again, and leaving it there would quietly strip
  /// them of every hectare they earned before making an account. Returns how many plots moved.
  Future<int> adoptGroundFrom(String previousOwnerId) async {
    final current = _player.id;
    if (previousOwnerId == current) return 0;

    // Scoped to the previous owner, so a rival's plot is never swept up by this.
    final mine = await _territories.getByOwner(previousOwnerId);
    if (mine.isEmpty) return 0;

    await _territories.upsertAll([
      for (final t in mine)
        t.copyWith(
          ownerId: current,
          ownerName: _player.name,
          colorHex: _player.colorHex,
        ),
    ]);
    return mine.length;
  }

  /// What this player holds, as the leaderboard counts it.
  ///
  /// Unverified ground is excluded, exactly as [watchLeaderboard] excludes it — a run that
  /// failed the gait check keeps its ground on the map but must never be published as a score.
  Future<({double totalAreaM2, int territoryCount})> currentStanding() async {
    final mine = await _territories.getByOwner(_player.id);
    final scoring = mine.where((t) => t.verified);
    return (
      totalAreaM2: scoring.fold(0.0, (sum, t) => sum + t.areaM2),
      territoryCount: scoring.length,
    );
  }

  // ------------------------------------------------------------------------- runs

  Future<Run> saveRun({
    required String id,
    required String title,
    required bool isPublic,
    required int startedAt,
    required int durationMs,
    required double distanceM,
    required int steps,
    required double elevationGainM,
    required double areaM2,
    required bool verified,
    required double plausibleRatio,
    required LatLng reference,
    required List<LatLng> track,
    List<ElevationSample> elevationSeries = const [],
  }) async {
    final run = Run(
      id: id,
      title: title,
      isPublic: isPublic,
      startedAt: startedAt,
      durationMs: durationMs,
      distanceM: distanceM,
      steps: steps,
      elevationGainM: elevationGainM,
      areaM2: areaM2,
      verified: verified,
      plausibleRatio: plausibleRatio,
      refLat: reference.latitude,
      refLng: reference.longitude,
      encodedPath: PathCodec.encode(track),
      encodedElevation: ElevationCodec.encode(elevationSeries),
    );
    await _runs.insert(run);
    // Returned so the caller can mirror exactly what was stored, rather than rebuilding a
    // second version of it from the same arguments and risking the two drifting apart.
    return run;
  }

  // --------------------------------------------------------------- rival seeding

  /// Stand-in for other players until a backend is wired up.
  ///
  /// Runs once, positioned around wherever the user actually is, so the map is never an empty
  /// grey field on first launch and the steal mechanic can be demonstrated solo.
  Future<void> seedRivalsAround(LatLng centre) async {
    if (await _territories.count() > 0) return;

    const rivals = [
      (name: 'Mara', color: '#2E86DE', bearing: 0.0),
      (name: 'Jonas', color: '#27AE60', bearing: 120.0),
      (name: 'Vik', color: '#8E44AD', bearing: 240.0),
    ];

    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = <Territory>[];

    for (var i = 0; i < rivals.length; i++) {
      final rival = rivals[i];
      final patchCentre = _offsetMetres(centre, rival.bearing, 260.0 + i * 90.0);
      final ring = _blobAround(patchCentre, 130.0 + i * 25.0, i);
      final geometry = TerritoryEngine.buildTerritoryGeographic(
        ring,
        patchCentre,
      );
      if (geometry == null) continue;

      rows.add(
        Territory(
          id: 'seed-${rival.name}',
          ownerId: 'rival-${rival.name}',
          ownerName: rival.name,
          colorHex: rival.color,
          wkt: TerritoryEngine.toWkt(geometry),
          areaM2: TerritoryEngine.areaM2(geometry),
          geohash5: Projection.geohash5(patchCentre),
          refLat: patchCentre.latitude,
          refLng: patchCentre.longitude,
          claimedAt: now - (i + 1) * 86400000,
          // One unverified rival, so the hatched style is visible from first launch.
          verified: i != 2,
        ),
      );
    }

    if (rows.isNotEmpty) await _territories.upsertAll(rows);
  }

  LatLng _offsetMetres(LatLng from, double bearingDeg, double metres) {
    final rad = bearingDeg * math.pi / 180.0;
    return LatLng(
      from.latitude + math.cos(rad) * metres / Projection.metresPerDegreeLat,
      from.longitude +
          math.sin(rad) * metres / Projection.metresPerDegreeLon(from.latitude),
    );
  }

  /// A wobbly ring, so seeded ground looks run rather than drawn.
  List<LatLng> _blobAround(LatLng centre, double radiusM, int seed) {
    const steps = 28;
    return [
      for (var i = 0; i < steps; i++)
        () {
          final angle = 2 * math.pi * i / steps;
          final wobble = 1.0 + 0.22 * math.sin(angle * (3 + seed) + seed);
          return _offsetMetres(centre, angle * 180.0 / math.pi, radiusM * wobble);
        }(),
    ];
  }
}
