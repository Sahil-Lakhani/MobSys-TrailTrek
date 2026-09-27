import 'package:drift/drift.dart';

@TableIndex(name: 'territories_geohash5', columns: {#geohash5})
@TableIndex(name: 'territories_owner', columns: {#ownerId})
class Territories extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get ownerName => text()();
  TextColumn get colorHex => text()();

  TextColumn get wkt => text()();

  RealColumn get areaM2 => real()();
  TextColumn get geohash5 => text()();

  RealColumn get refLat => real()();
  RealColumn get refLng => real()();

  IntColumn get claimedAt => integer()();
  BoolColumn get verified => boolean()();

  IntColumn get rev => integer().withDefault(const Constant(0))();

  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Runs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  BoolColumn get isPublic => boolean()();
  IntColumn get startedAt => integer()();
  IntColumn get durationMs => integer()();
  RealColumn get distanceM => real()();
  IntColumn get steps => integer()();
  RealColumn get elevationGainM => real()();
  RealColumn get areaM2 => real()();
  BoolColumn get verified => boolean()();
  RealColumn get plausibleRatio => real()();
  RealColumn get refLat => real()();
  RealColumn get refLng => real()();

  TextColumn get encodedPath => text()();

  TextColumn get encodedElevation => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'trails_geohash5', columns: {#geohash5})
class Trails extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  RealColumn get lengthM => real()();
  TextColumn get encodedPath => text()();
  TextColumn get geohash5 => text()();
  IntColumn get cachedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TrailCells extends Table {
  TextColumn get geohash5 => text()();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {geohash5};
}
