import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftAccessor(tables: [Territories])
class TerritoryDao extends DatabaseAccessor<ClaimTrekDatabase>
    with _$TerritoryDaoMixin {
  TerritoryDao(super.db);

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

  Future<List<Territory>> getInCells(List<String> cells) => (select(
    territories,
  )..where((t) => _live(t) & t.geohash5.isIn(cells))).get();

  Future<List<Territory>> getByOwner(String ownerId) => (select(
    territories,
  )..where((t) => _live(t) & t.ownerId.equals(ownerId))).get();

  Future<Territory?> byId(String id) =>
      (select(territories)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Territory>> getDirty() =>
      (select(territories)..where((t) => t.dirty.equals(true))).get();

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

  Future<int?> cellFetchedAt(String cell) async {
    final row = await (select(
      trailCells,
    )..where((t) => t.geohash5.equals(cell))).getSingleOrNull();
    return row?.fetchedAt;
  }

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

  static final DriftWebOptions _webOptions = DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  );

  ClaimTrekDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(trailCells);
      if (from < 3) await m.addColumn(runs, runs.encodedElevation);
      if (from < 4) {
        await m.addColumn(territories, territories.rev);
        await m.addColumn(territories, territories.dirty);
        await customStatement(
          "UPDATE territories SET dirty = 1 WHERE id NOT LIKE 'seed-%'",
        );
      }
    },
  );
}
