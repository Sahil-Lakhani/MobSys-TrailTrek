import 'package:claimtrek/geo/wkt.dart';
import 'package:clipper2/clipper2.dart';
import 'package:test/test.dart';

PathD rect(double x, double y, double w, double h) => [
  PointD(x, y),
  PointD(x + w, y),
  PointD(x + w, y + h),
  PointD(x, y + h),
];

void main() {
  test('a simple square round-trips', () {
    final source = <PathD>[rect(0, 0, 100, 100)];
    final wkt = writeWkt(source);
    expect(wkt, startsWith('POLYGON ('));

    final restored = readWkt(wkt)!;
    expect(restored.length, 1);
    expect(restored.area.abs(), closeTo(10000, 0.001));
  });

  test('a polygon with a hole keeps the hole', () {
    // A rival carved out of the middle of your ground: the hole is the whole point.
    final shell = rect(0, 0, 100, 100);
    final hole = rect(25, 25, 50, 50).reversed.toList(); // negative orientation
    final source = <PathD>[shell, hole];
    expect(source.area, closeTo(7500, 0.001));

    final wkt = writeWkt(source);
    expect(wkt, startsWith('POLYGON ('));

    final restored = readWkt(wkt)!;
    expect(restored.length, 2);
    expect(restored.area, closeTo(7500, 0.001));
  });

  test('two disjoint shells become a MULTIPOLYGON', () {
    final source = <PathD>[rect(0, 0, 100, 100), rect(500, 0, 100, 100)];
    final wkt = writeWkt(source);
    expect(wkt, startsWith('MULTIPOLYGON ('));

    final restored = readWkt(wkt)!;
    expect(restored.length, 2);
    expect(restored.area.abs(), closeTo(20000, 0.001));
  });

  test('geographic precision survives the round trip', () {
    // Degrees need far more than the two decimal places clipper's own tree walk would keep;
    // 0.01 degrees is about a kilometre. This is the regression guard for that.
    final source = <PathD>[
      [
        const PointD(10.4482999999999997, 50.7216999999999985),
        const PointD(10.4490094681432933, 50.7216999999999985),
        const PointD(10.4490094681432933, 50.7218122888968708),
        const PointD(10.4482999999999997, 50.7218122888968708),
      ],
    ];
    final restored = readWkt(writeWkt(source))!;
    for (var i = 0; i < source.single.length; i++) {
      expect(restored.single[i].x, closeTo(source.single[i].x, 1e-12));
      expect(restored.single[i].y, closeTo(source.single[i].y, 1e-12));
    }
  });

  test('orientation is normalised regardless of how the source wrote it', () {
    // A shell written clockwise by some other tool must still read back as a positive shell,
    // or every area in the app comes out negative.
    const backwards =
        'POLYGON ((0 0, 0 100, 100 100, 100 0, 0 0))';
    final restored = readWkt(backwards)!;
    expect(restored.single.area, greaterThan(0));
    expect(restored.area, closeTo(10000, 0.001));
  });

  test('the explicit closing vertex is not duplicated', () {
    final restored = readWkt('POLYGON ((0 0, 100 0, 100 100, 0 100, 0 0))')!;
    expect(restored.single.length, 4);
  });

  test('empty geometry round-trips', () {
    expect(writeWkt(<PathD>[]), 'POLYGON EMPTY');
    expect(readWkt('POLYGON EMPTY'), isEmpty);
  });

  test('malformed input returns null instead of throwing', () {
    expect(readWkt('not a geometry'), isNull);
    expect(readWkt('POLYGON ((0 0, 100'), isNull);
    expect(readWkt('POLYGON ((0 0, oops 5, 1 1, 0 0))'), isNull);
    expect(readWkt(''), isNull);
    expect(readWkt('LINESTRING (0 0, 1 1)'), isNull);
  });

  test('a degenerate ring is dropped rather than stored', () {
    // Two points cannot bound anything.
    expect(readWkt('POLYGON ((0 0, 1 1, 0 0))'), isEmpty);
  });
}
