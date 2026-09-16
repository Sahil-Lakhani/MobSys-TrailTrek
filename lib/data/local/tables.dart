import 'package:drift/drift.dart';

/// Local storage is the source of truth the app opens with. A backend, when it lands, mirrors
/// into these tables rather than replacing them — the app has to work on a train with no
/// signal.

@TableIndex(name: 'territories_geohash5', columns: {#geohash5})
@TableIndex(name: 'territories_owner', columns: {#ownerId})
class Territories extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get ownerName => text()();
  TextColumn get colorHex => text()();

  /// Geographic WKT. Stored in degrees so it can be reloaded next to any other territory,
  /// whatever reference point that one was projected about.
  TextColumn get wkt => text()();

  RealColumn get areaM2 => real()();
  TextColumn get geohash5 => text()();

  /// The run's projection origin. Kept so the exact metre frame can be reconstructed.
  RealColumn get refLat => real()();
  RealColumn get refLng => real()();

  IntColumn get claimedAt => integer()();
  BoolColumn get verified => boolean()();

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

  /// "lat,lng;lat,lng;..." — one column, no join table for a few hundred points.
  TextColumn get encodedPath => text()();

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

/// When a map cell was last asked about.
///
/// Separate from [Trails] because an area with no trails still has to be remembered. With only
/// the rows to go on, "we asked and there is nothing here" and "we never asked" look identical,
/// so an empty region would re-query Overpass on every visit — and Overpass rate-limits.
class TrailCells extends Table {
  TextColumn get geohash5 => text()();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {geohash5};
}
