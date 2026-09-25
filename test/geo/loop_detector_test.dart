import 'package:claimtrek/geo/loop_detector.dart';
import 'package:test/test.dart';

import 'geo_test_support.dart';

void main() {
  test('an empty or tiny track is never closed', () {
    expect(LoopDetector.isClosed([]), isFalse);
    expect(LoopDetector.isClosed([GeoTestSupport.ref]), isFalse);
  });

  test('standing still does not count as a loop', () {
    // 40 fixes in the same spot: first and last are metres apart, but nothing was travelled.
    final stationary = List.generate(
      40,
      (i) => GeoTestSupport.point(i * 0.1, 0),
    );
    expect(LoopDetector.isClosed(stationary), isFalse);
  });

  test('an out and back that never returns is not closed', () {
    final outbound = List.generate(41, (i) => GeoTestSupport.point(i * 10.0, 0));
    expect(LoopDetector.isClosed(outbound), isFalse);
  });

  test('a square lap closes', () {
    expect(LoopDetector.isClosed(GeoTestSupport.square(120)), isTrue);
  });

  test('a lap that stops twenty metres short still closes', () {
    final lap = GeoTestSupport.square(120).sublist(0, 32)
      ..add(GeoTestSupport.point(0, 20));
    expect(LoopDetector.isClosed(lap), isTrue);
  });

  test('a lap that ends sixty metres from the start still closes', () {
    final lap = GeoTestSupport.square(120).sublist(0, 32)
      ..add(GeoTestSupport.point(0, 60));
    expect(LoopDetector.isClosed(lap), isTrue);
  });

  test('a lap that ends eighty metres from the start does not close', () {
    final lap = GeoTestSupport.square(120).sublist(0, 32)
      ..add(GeoTestSupport.point(0, 80));
    expect(LoopDetector.isClosed(lap), isFalse);
  });

  test('closure progress rises as the runner comes home', () {
    final lap = GeoTestSupport.square(120);
    final halfway = lap.sublist(0, lap.length ~/ 2);
    expect(
      LoopDetector.closureProgress(halfway),
      lessThan(LoopDetector.closureProgress(lap)),
    );
    expect(LoopDetector.closureProgress(lap), closeTo(1.0, 0.05));
  });

  test('distance to start measures the open gap', () {
    expect(LoopDetector.distanceToStart([]), 0.0);
    expect(LoopDetector.distanceToStart(GeoTestSupport.square(120)), closeTo(0, 0.5));
  });
}
