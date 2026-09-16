import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// Territory reads and writes.
@DriftAccessor(tables: [Territories])
class TerritoryDao extends DatabaseAccessor<ClaimTrekDatabase>
    with _$TerritoryDaoMixin {
  TerritoryDao(super.db);

  Stream<List<Territory>> watchAll() =>
      (select(territories)..orderBy([
            (t) => OrderingTerm(expression: t.claimedAt, mode: OrderingMode.desc),
          ]))
          .watch();

  Future<List<Territory>> getAll() => select(territories).get();

  /// Nearby means "same ~5 km geohash cell", plus any others the caller passes.
  Future<List<Territory>> getInCells(List<String> cells) =>
      (select(territories)..where((t) => t.geohash5.isIn(cells))).get();

  Future<List<Territory>> getByOwner(String ownerId) =>
      (select(territories)..where((t) => t.ownerId.equals(ownerId))).get();

  Future<void> upsert(Territory territory) =>
      into(territories).insertOnConflictUpdate(territory);

  Future<void> upsertAll(List<Territory> rows) => batch(
    (b) => b.insertAllOnConflictUpdate(territories, rows),
  );

  Future<void> deleteByIds(List<String> ids) =>
      (delete(territories)..where((t) => t.id.isIn(ids))).go();

  Future<int> count() async {
    final expression = territories.id.count();
    final row = await (selectOnly(territories)..addColumns([expression]))
        .getSingle();
    return row.read(expression) ?? 0;
  }
}

@DriftAccessor(tables: [Runs])
class RunDao extends DatabaseAccessor<ClaimTrekDatabase> with _$RunDaoMixin {
  RunDao(super.db);

  Stream<List<Run>> watchAll() =>
      (select(runs)..orderBy([
            (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
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
  Future<void> evictOlderThan(int cutoffMillis) =>
      (delete(trails)..where((t) => t.cachedAt.isSmallerThanValue(cutoffMillis)))
          .go();

  Future<void> replaceCell(String cell, List<Trail> rows) => transaction(() async {
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
    final row = await (select(trailCells)
          ..where((t) => t.geohash5.equals(cell)))
        .getSingleOrNull();
    return row?.fetchedAt;
  }

  /// Ages every cell out at once. Used by tests, and by a manual refresh.
  Future<void> expireAllCells() => update(trailCells).write(
    const TrailCellsCompanion(fetchedAt: Value(0)),
  );
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
  int get schemaVersion => 2;

  /// v2 adds [TrailCells]. Creating just the new table rather than wiping means an existing
  /// install keeps its claimed territory — losing someone's ground to a schema bump would be
  /// the worst possible upgrade.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(trailCells);
    },
  );
}
