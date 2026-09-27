import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/geo/territory_engine.dart';
import 'package:clipper2/clipper2.dart';
import 'package:test/test.dart';

import 'geo_test_support.dart';

void main() {
  Claim claimOf(String id, String owner, List<LatLng> track) {
    final geometry = TerritoryEngine.buildTerritoryGeographic(
      track,
      GeoTestSupport.ref,
    )!;
    return Claim(
      id: id,
      ownerId: owner,
      geometry: geometry,
      areaM2: TerritoryEngine.areaM2(geometry),
    );
  }

  test('a hundred metre square measures ten thousand square metres', () {
    final geometry = TerritoryEngine.buildTerritory(
      GeoTestSupport.square(100),
      GeoTestSupport.ref,
    )!;
    expect(geometry.area, closeTo(10000, 1.0));
  });

  test('area survives the round trip through geographic coordinates', () {
    final metres = TerritoryEngine.buildTerritory(
      GeoTestSupport.square(100),
      GeoTestSupport.ref,
    )!;
    final geographic = TerritoryEngine.toGeographic(metres, GeoTestSupport.ref);
    expect(TerritoryEngine.areaM2(geographic), closeTo(metres.area, 1.0));
  });

  test('a self-intersecting track is repaired rather than rejected', () {
    final geometry = TerritoryEngine.buildTerritory(
      GeoTestSupport.figureEight(),
      GeoTestSupport.ref,
    );
    expect(geometry, isNotNull);
    expect(
      geometry!.length,
      2,
      reason: 'a bowtie must come back as two separate lobes, not one bad ring',
    );
    expect(
      geometry.area.abs(),
      greaterThan(1000),
      reason: 'both lobes should survive',
    );
  });

  test('too few points produces no territory', () {
    expect(
      TerritoryEngine.buildTerritory([GeoTestSupport.ref], GeoTestSupport.ref),
      isNull,
    );
    expect(TerritoryEngine.buildTerritory([], GeoTestSupport.ref), isNull);
  });

  test('an overlapping claim takes exactly the overlap', () {
    final defender = claimOf('a', 'rival', GeoTestSupport.square(100));
    expect(defender.areaM2, closeTo(10000, 1.0));

    final attacker = TerritoryEngine.buildTerritoryGeographic(
      GeoTestSupport.shifted(GeoTestSupport.square(100), 50, 0),
      GeoTestSupport.ref,
    )!;

    final survivors = TerritoryEngine.resolveClaim(attacker, [defender]);
    expect(survivors.length, 1);
    expect(survivors.first.areaM2, closeTo(5000, 5.0));
  });

  test('a claim that misses everything changes nothing', () {
    final defender = claimOf('a', 'rival', GeoTestSupport.square(100));
    final attacker = TerritoryEngine.buildTerritoryGeographic(
      GeoTestSupport.shifted(GeoTestSupport.square(100), 5000, 0),
      GeoTestSupport.ref,
    )!;

    final survivors = TerritoryEngine.resolveClaim(attacker, [defender]);
    expect(survivors, [defender]);
  });

  test('a territory reduced to a sliver is dropped entirely', () {
    final defender = claimOf('a', 'rival', GeoTestSupport.square(100));

    final attacker = TerritoryEngine.buildTerritoryGeographic(
      GeoTestSupport.shifted(GeoTestSupport.square(300), 0.2, -100),
      GeoTestSupport.ref,
    )!;

    final survivors = TerritoryEngine.resolveClaim(attacker, [defender]);
    expect(survivors, isEmpty, reason: 'a sliver is not land worth keeping');
  });

  test("merging a runner's own claims yields one holding", () {
    final existing = claimOf('mine', 'me', GeoTestSupport.square(100));
    final fresh = TerritoryEngine.buildTerritoryGeographic(
      GeoTestSupport.shifted(GeoTestSupport.square(100), 50, 0),
      GeoTestSupport.ref,
    )!;

    final merged = TerritoryEngine.mergeOwn(fresh, [existing]);
    expect(TerritoryEngine.areaM2(merged), closeTo(15000, 10.0));
  });

  test('WKT survives a round trip', () {
    final geometry = TerritoryEngine.buildTerritoryGeographic(
      GeoTestSupport.square(100),
      GeoTestSupport.ref,
    )!;
    final restored = TerritoryEngine.fromWkt(TerritoryEngine.toWkt(geometry))!;
    expect(
      TerritoryEngine.areaM2(restored),
      closeTo(TerritoryEngine.areaM2(geometry), 0.5),
    );
  });

  test('malformed WKT returns null instead of throwing', () {
    expect(TerritoryEngine.fromWkt('not a geometry'), isNull);
  });
}
