import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/geo/projection.dart';
import 'package:test/test.dart';

import 'geo_test_support.dart';

void main() {
  test('project then unproject returns the original point', () {
    const original = LatLng(50.7250, 10.4550);
    final roundTripped = Projection.unproject(
      Projection.project(original, GeoTestSupport.ref),
      GeoTestSupport.ref,
    );
    expect(roundTripped.latitude, closeTo(original.latitude, 1e-9));
    expect(roundTripped.longitude, closeTo(original.longitude, 1e-9));
  });

  test('one hundred metres north projects to one hundred metres', () {
    final north = GeoTestSupport.point(0, 100);
    final c = Projection.project(north, GeoTestSupport.ref);
    expect(c.x, closeTo(0, 1e-6));
    expect(c.y, closeTo(100, 1e-6));
  });

  test('haversine agrees with the flat projection over short distances', () {
    final a = GeoTestSupport.ref;
    final b = GeoTestSupport.point(300, 400);
    // 3-4-5: the flat answer is 500 m, and over half a kilometre curvature is negligible.
    expect(Projection.haversine(a, b), closeTo(500, 1.0));
  });

  test('bearing due east is ninety degrees', () {
    final east = GeoTestSupport.point(500, 0);
    expect(Projection.bearing(GeoTestSupport.ref, east), closeTo(90, 0.5));
  });

  test('path length sums the legs', () {
    final track = [
      GeoTestSupport.point(0, 0),
      GeoTestSupport.point(100, 0),
      GeoTestSupport.point(100, 100),
    ];
    expect(Projection.pathLength(track), closeTo(200, 1.0));
  });

  test('geohash is prefix-nested and separates distant places', () {
    final here = GeoTestSupport.ref;
    const farAway = LatLng(48.1372, 11.5756); // Munich

    final cell = Projection.geohash5(here);
    expect(cell.length, 5);
    // Prefix nesting is the whole point: a shorter hash is a bigger cell containing it.
    expect(cell.startsWith(Projection.geohash(here, 3)), isTrue);
    expect(cell, isNot(Projection.geohash5(farAway)));
  });
}
