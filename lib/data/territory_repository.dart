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

class TerritoryRepository {
  TerritoryRepository(this._db, this._player, [this._uuid = const Uuid()]);

  final ClaimTrekDatabase _db;
  final PlayerIdentity _player;
  final Uuid _uuid;

  static const double _meaningfulLossM2 = 1.0;

  TerritoryDao get _territories => _db.territoryDao;
  RunDao get _runs => _db.runDao;

  Stream<List<Territory>> watchTerritories() => _territories.watchAll();

  Stream<List<Run>> watchRuns() => _runs.watchAll();

  Stream<List<LeaderboardEntry>> watchLeaderboard() =>
      _territories.watchAll().map(_toLeaderboard);

  List<LeaderboardEntry> _toLeaderboard(List<Territory> rows) {
    final byOwner = <String, List<Territory>>{};
    for (final row in rows.where((r) => r.verified)) {
      byOwner.putIfAbsent(row.ownerId, () => []).add(row);
    }

    final entries = byOwner.entries.map((e) {
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
    }).toList()..sort((a, b) => b.totalAreaM2.compareTo(a.totalAreaM2));

    return [
      for (var i = 0; i < entries.length; i++) entries[i].withRank(i + 1),
    ];
  }

  static Territory tombstone(Territory row) =>
      row.copyWith(wkt: '', areaM2: 0, rev: row.rev + 1, dirty: true);

  static bool isLocalOnly(Territory row) => row.id.startsWith('seed-');

  Future<List<Claim>> _rivalClaims() async {
    final rows = await _territories.getAll();
    return _toClaims(rows.where((r) => r.ownerId != _player.id));
  }

  List<Claim> _toClaims(Iterable<Territory> rows) {
    final out = <Claim>[];
    for (final row in rows) {
      final geometry = TerritoryEngine.fromWkt(row.wkt);
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

  Future<ClaimPreview> previewClaim(PathsD claimGeographic) async {
    final rivals = await _rivalClaims();
    final losses = _losses(
      rivals,
      TerritoryEngine.resolveClaim(claimGeographic, rivals),
    );
    return ClaimPreview(
      stolenAreaM2: losses.area,
      stolenFromCount: losses.count,
    );
  }

  ({double area, int count}) _losses(List<Claim> before, List<Claim> after) {
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

    final updates = <Territory>[];
    for (final survivor in survivors) {
      final original = rivals.firstWhere((c) => c.id == survivor.id);
      if (original.areaM2 <= survivor.areaM2 + _meaningfulLossM2) continue;
      final row = rivalRows.firstWhere((r) => r.id == survivor.id);
      updates.add(
        row.copyWith(
          wkt: TerritoryEngine.toWkt(survivor.geometry),
          areaM2: survivor.areaM2,
          rev: row.rev + 1,
          dirty: true,
        ),
      );
    }

    final wipedOutIds = {
      for (final c in rivals)
        if (!survivorsById.containsKey(c.id)) c.id,
    };
    updates.addAll(
      rivalRows.where((r) => wipedOutIds.contains(r.id)).map(tombstone),
    );

    final merged = TerritoryEngine.mergeOwn(
      claimGeographic,
      _toClaims(ownRows),
    );
    updates.addAll(ownRows.map(tombstone));
    if (updates.isNotEmpty) await _territories.upsertAll(updates);

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
        rev: 1,
        dirty: true,
      ),
    );

    return ClaimOutcome(
      territoryId: id,
      areaM2: area,
      stolenAreaM2: losses.area,
      stolenFromCount: losses.count,
    );
  }

  Future<int> adoptGroundFrom(String previousOwnerId) async {
    final current = _player.id;
    if (previousOwnerId == current) return 0;

    final mine = await _territories.getByOwner(previousOwnerId);
    if (mine.isEmpty) return 0;

    await _territories.upsertAll([
      for (final t in mine)
        t.copyWith(
          ownerId: current,
          ownerName: _player.name,
          colorHex: _player.colorHex,
          rev: t.rev + 1,
          dirty: true,
        ),
    ]);
    return mine.length;
  }

  Future<({double totalAreaM2, int territoryCount})> currentStanding() async {
    final mine = await _territories.getByOwner(_player.id);
    final scoring = mine.where((t) => t.verified);
    return (
      totalAreaM2: scoring.fold(0.0, (sum, t) => sum + t.areaM2),
      territoryCount: scoring.length,
    );
  }

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
    return run;
  }

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
      final patchCentre = _offsetMetres(
        centre,
        rival.bearing,
        260.0 + i * 90.0,
      );
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
          verified: i != 2,
          rev: 0,
          dirty: false,
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

  List<LatLng> _blobAround(LatLng centre, double radiusM, int seed) {
    const steps = 28;
    return [
      for (var i = 0; i < steps; i++)
        () {
          final angle = 2 * math.pi * i / steps;
          final wobble = 1.0 + 0.22 * math.sin(angle * (3 + seed) + seed);
          return _offsetMetres(
            centre,
            angle * 180.0 / math.pi,
            radiusM * wobble,
          );
        }(),
    ];
  }
}
