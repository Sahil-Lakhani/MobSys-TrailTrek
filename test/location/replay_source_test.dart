import 'dart:io';

import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/geo/loop_detector.dart';
import 'package:claimtrek/geo/projection.dart';
import 'package:claimtrek/location/location_source.dart';
import 'package:claimtrek/location/replay_source.dart';
import 'package:test/test.dart';

void main() {
  group('GPX parsing', () {
    test('reads the bundled demo loop', () {
      final gpx = File('assets/demo_loop.gpx').readAsStringSync();
      final points = ReplaySource.parseGpx(gpx);

      expect(points, hasLength(207));
      expect(points.first.elevationM, isNotNull);
      expect(points.first.time, isNotNull);
      expect(points.first.point.latitude, closeTo(50.7217, 0.01));
      expect(points.first.point.longitude, closeTo(10.4483, 0.01));
    });

    test('the demo loop actually closes, or the fixture is useless', () {
      final gpx = File('assets/demo_loop.gpx').readAsStringSync();
      final track = ReplaySource.parseGpx(gpx).map((p) => p.point).toList();

      expect(Projection.pathLength(track), greaterThan(1000));
      expect(
        LoopDetector.isClosed(track),
        isTrue,
        reason: 'the demo fixture must close or it cannot demonstrate a claim',
      );
    });

    test('handles self-closing trkpt tags and missing children', () {
      const gpx = '''
<gpx><trk><trkseg>
  <trkpt lat="50.7217" lon="10.4483"/>
  <trkpt lat="50.7218" lon="10.4484"><ele>321.5</ele></trkpt>
</trkseg></trk></gpx>''';
      final points = ReplaySource.parseGpx(gpx);
      expect(points, hasLength(2));
      expect(points.first.elevationM, isNull);
      expect(points.first.time, isNull);
      expect(points[1].elevationM, 321.5);
    });

    test('ignores junk instead of throwing', () {
      expect(ReplaySource.parseGpx(''), isEmpty);
      expect(ReplaySource.parseGpx('<gpx></gpx>'), isEmpty);
      expect(
        ReplaySource.parseGpx('<trkpt lat="nope" lon="10.4"></trkpt>'),
        isEmpty,
      );
    });
  });

  group('fix filtering', () {
    Fix fix({double accuracy = 6, double speed = 2}) => Fix(
      point: const LatLng(50.7217, 10.4483),
      accuracyM: accuracy,
      speedMs: speed,
      timestampMs: 0,
    );

    test('a good fix is accepted', () {
      expect(LocationSource.accept(fix()), isTrue);
    });

    test('a wildly inaccurate fix is rejected', () {
      // One 60 m outlier turns a neat loop into a spike swallowing a city block.
      expect(LocationSource.accept(fix(accuracy: 60)), isFalse);
    });

    test('an unreported accuracy is rejected', () {
      expect(LocationSource.accept(fix(accuracy: 0)), isFalse);
    });

    test('vehicle speed is rejected', () {
      expect(LocationSource.accept(fix(speed: 25)), isFalse);
    });
  });

  group('playback', () {
    test('replays every point in order and then closes', () async {
      final gpx = File('assets/demo_loop.gpx').readAsStringSync();
      // 500x compression keeps the test fast while exercising the real timing path.
      final source = ReplaySource.fromGpx(gpx, speedX: 500);

      final received = await source.start().toList();

      expect(received, hasLength(207));
      expect(received.first.point.latitude, closeTo(50.7217, 0.01));
      // Speed is derived from consecutive fixes; a ~3 m/s walk over 2 s samples.
      expect(received[5].speedMs, greaterThan(0));
      expect(received.every(LocationSource.accept), isTrue);
    });

    test('stop ends the stream early', () async {
      final gpx = File('assets/demo_loop.gpx').readAsStringSync();
      final source = ReplaySource.fromGpx(gpx, speedX: 200);

      final seen = <Fix>[];
      final done = source.start().listen(seen.add).asFuture<void>();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await source.stop();
      await done;

      expect(seen.length, lessThan(207));
    });
  });
}
