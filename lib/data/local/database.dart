import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// Territory reads and writes.
@DriftAccessor(tables: [Territories])
class TerritoryDao extends DatabaseAccessor<ClaimTrekDatabase>
    with _$TerritoryDaoMixin {
  TerritoryDao(super.db);

  /// A territory that has been taken entirely, or folded into a newer one, is kept as an empty
  /// row until the removal has been published — deleting it outright would leave nothing to
  /// tell the other devices. These reads are the living ground only.
  Expression<bool> _live($TerritoriesTable t) => t.areaM2.isBiggerThanValue(0);

  Stream<List<Territory>> watchAll() =>
      (select(territories)
            ..where(_live)
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.claimedAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Future<List<Territory>> getAll() => (select(territories)..where(_live)).get();

  /// Nearby means "same ~5 km geohash cell", plus any others the caller passes.
  Future<List<Territory>> getInCells(List<String> cells) => (select(
    territories,
  )..where((t) => _live(t) & t.geohash5.isIn(cells))).get();

  Future<List<Territory>> getByOwner(String ownerId) => (select(
    territories,
  )..where((t) => _live(t) & t.ownerId.equals(ownerId))).get();

  /// One row by id, living or removed.
  Future<Territory?> byId(String id) =>
      (select(territories)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Every row still waiting to be published, removals included.
  Future<List<Territory>> getDirty() =>
      (select(territories)..where((t) => t.dirty.equals(true))).get();

  /// Marks a row as published, but only if nothing changed it while the upload was in flight.
  ///
  /// Compare-and-set on [expectedRev]: a claim that lands mid-upload bumps the revision, and
  /// clearing the flag regardless would silently drop that claim from the next upload. When
  /// the upload itself changed the geometry (a merge with someone else's steal), the merged
  /// result is written back in the same step. Returns whether the row was updated.
  Future<bool> markPublished(
    String id, {
    required int expectedRev,
    required int newRev,
    String? wkt,
    double? areaM2,
  }) async {
    final changed =
        await (update(
          territories,
        )..where((t) => t.id.equals(id) & t.rev.equals(expectedRev))).write(
          TerritoriesCompanion(
            rev: Value(newRev),
            dirty: const Value(false),
            wkt: wkt == null ? const Value.absent() : Value(wkt),
            areaM2: areaM2 == null ? const Value.absent() : Value(areaM2),
          ),
        );
    return changed > 0;
  }

  Future<void> upsert(Territory territory) =>
      into(territories).insertOnConflictUpdate(territory);

  Future<void> upsertAll(List<Territory> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(territories, rows));

  /// Deletes a row unless it changed since [rev] was read — the same guard as
  /// [markPublished], for a removal that has finished publishing.
  Future<void> deleteIfRev(String id, int rev) => (delete(
    territories,
  )..where((t) => t.id.equals(id) & t.rev.equals(rev))).go();

  Future<void> deleteByIds(List<String> ids) =>
      (delete(territories)..where((t) => t.id.isIn(ids))).go();

  Future<int> count() async {
    final expression = territories.id.count();
    final row = await (selectOnly(
      territories,
    )..addColumns([expression])).getSingle();
    return row.read(expression) ?? 0;
  }
}

@DriftAccessor(tables: [Runs])
class RunDao extends DatabaseAccessor<ClaimTrekDatabase> with _$RunDaoMixin {
  RunDao(super.db);

  Stream<List<Run>> watchAll() =>
      (select(runs)..orderBy([
            (t) =>
                OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
          ]))
          .watch();

  Future<Run?> byId(String id) =>
      (select(runs)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insert(Run run) => into(runs).insertOnConflictUpdate(run);

  Future<void> rename(String id, String title, bool isPublic) =>
      (update(runs)..where((t) => t.id.equals(id))).write(
        RunsCompanion(title: Value(title), isPublic: Value(isPublic)),
      );

  Future<void> deleteById(String id) =>
      (delete(runs)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [Trails, TrailCells])
class TrailDao extends DatabaseAccessor<ClaimTrekDatabase>
    with _$TrailDaoMixin {
  TrailDao(super.db);

  Future<List<Trail>> getInCells(List<String> cells) =>
      (select(trails)
            ..where((t) => t.geohash5.isIn(cells))
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.lengthM, mode: OrderingMode.desc),
            ]))
          .get();

  Future<void> upsertAll(List<Trail> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(trails, rows));

  /// Overpass rate-limits, so results are cached; this is how the cache is aged out.
  Future<void> evictOlderThan(int cutoffMillis) => (delete(
    trails,
  )..where((t) => t.cachedAt.isSmallerThanValue(cutoffMillis))).go();

  Future<void> replaceCell(String cell, List<Trail> rows) =>
      transaction(() async {
        await (delete(trails)..where((t) => t.geohash5.equals(cell))).go();
        if (rows.isNotEmpty) await upsertAll(rows);
        await into(trailCells).insertOnConflictUpdate(
          TrailCell(
            geohash5: cell,
            fetchedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      });

  /// Null when the cell has never been fetched, which is not the same as fetched-and-empty.
  Future<int?> cellFetchedAt(String cell) async {
    final row = await (select(
      trailCells,
    )..where((t) => t.geohash5.equals(cell))).getSingleOrNull();
    return row?.fetchedAt;
  }

  /// Ages every cell out at once. Used by tests, and by a manual refresh.
  Future<void> expireAllCells() =>
      update(trailCells).write(const TrailCellsCompanion(fetchedAt: Value(0)));
}

@DriftDatabase(
  tables: [Territories, Runs, Trails, TrailCells],
  daos: [TerritoryDao, RunDao, TrailDao],
)
class ClaimTrekDatabase extends _$ClaimTrekDatabase {
  ClaimTrekDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'claimtrek', web: _webOptions));

  /// Required on web, ignored on native. `driftDatabase` throws synchronously without it, and
  /// the files must be served from `web/` at versions matching the resolved `sqlite3` and
  /// `drift` packages.
  static final DriftWebOptions _webOptions = DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  );

  /// For tests: a fresh database per case, with nothing on disk to leak between them.
  ClaimTrekDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  /// v2 adds [TrailCells]; v3 adds the elevation profile to [Runs]; v4 adds the revision and
  /// upload flag that let territory be shared between players. Adding rather than wiping
  /// means an existing install keeps its claimed territory — losing someone's ground to a
  /// schema bump would be the worst possible upgrade. Old runs simply carry an empty profile.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(trailCells);
      if (from < 3) await m.addColumn(runs, runs.encodedElevation);
      if (from < 4) {
        // v4 shares territory between players. Ground claimed before that existed has never
        // been published, so it is marked for upload — except the stand-in rivals, which are
        // local props and never leave the device.
        await m.addColumn(territories, territories.rev);
        await m.addColumn(territories, territories.dirty);
        await customStatement(
          "UPDATE territories SET dirty = 1 WHERE id NOT LIKE 'seed-%'",
        );
      }
    },
  );
}
