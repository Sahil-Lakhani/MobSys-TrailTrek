import 'package:claimtrek/ui/common/elevation_chart.dart';
import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/local/path_codec.dart';
import 'package:claimtrek/data/providers.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/ui/photos/photo_viewer_screen.dart';
import 'package:claimtrek/ui/runs/run_detail_screen.dart';
import 'package:claimtrek/ui/runs/runs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = [LatLng(50.7217, 10.4483), LatLng(50.7227, 10.4483)];

Run run({
  required String id,
  required String title,
  double areaM2 = 0,
  double distanceM = 1253,
  bool verified = true,
  String? encodedPath,
  String encodedElevation = '',
}) => Run(
  id: id,
  title: title,
  isPublic: false,
  startedAt: DateTime(2026, 9, 8, 7, 30).millisecondsSinceEpoch,
  durationMs: const Duration(minutes: 4, seconds: 12).inMilliseconds,
  distanceM: distanceM,
  steps: 812,
  elevationGainM: 14,
  areaM2: areaM2,
  verified: verified,
  plausibleRatio: verified ? 1.0 : 0.2,
  refLat: 50.7217,
  refLng: 10.4483,
  encodedPath: encodedPath ?? PathCodec.encode(_path),
  encodedElevation: encodedElevation,
);

void main() {
  Future<void> pumpList(WidgetTester tester, List<Run> runs) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runsProvider.overrideWith((ref) => Stream.value(runs)),
        ],
        child: const MaterialApp(home: RunsScreen()),
      ),
    );
    await tester.pump();
  }

  group('list', () {
    testWidgets('a run that claimed ground shows its area', (tester) async {
      await pumpList(tester, [run(id: '1', title: 'Morning run', areaM2: 32400)]);

      expect(find.text('Morning run'), findsOneWidget);
      expect(find.text('0.032 km²'), findsOneWidget);
    });

    testWidgets('a run that closed no loop reads "no loop", not "0 m²"', (
      tester,
    ) async {
      // Claiming nothing because the shape never closed is a different thing from claiming an
      // area of nothing, and the list should not make it look like a failed claim.
      await pumpList(tester, [run(id: '2', title: 'Aborted run')]);

      expect(find.text('no loop'), findsOneWidget);
      expect(find.text('0 km²'), findsNothing);
    });

    testWidgets('unclosed runs are listed alongside claimed ones', (tester) async {
      await pumpList(tester, [
        run(id: '1', title: 'Morning run', areaM2: 32400),
        run(id: '2', title: 'Aborted run'),
      ]);

      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.text('Aborted run'), findsOneWidget);
    });

    testWidgets('the row carries distance and time', (tester) async {
      await pumpList(tester, [run(id: '1', title: 'Morning run')]);

      expect(find.textContaining('1253 m'), findsOneWidget);
      expect(find.textContaining('4:12'), findsOneWidget);
    });

    testWidgets('an empty history explains itself', (tester) async {
      await pumpList(tester, const []);

      expect(find.text('No runs yet'), findsOneWidget);
    });
  });

  group('detail', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      Run value, {
      List<RunPhoto> photos = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runPhotosProvider.overrideWith(
              (ref, runId) => Stream<List<RunPhoto>>.value(photos),
            ),
          ],
          child: MaterialApp(home: RunDetailScreen(run: value)),
        ),
      );
      await tester.pump();
    }

    testWidgets('photos taken on the run are shown with it', (tester) async {
      await pumpDetail(
        tester,
        run(id: '3', title: 'Photo run'),
        photos: [
          for (var i = 0; i < 3; i++)
            RunPhoto(
              id: 'p$i',
              runId: '3',
              filePath: 'missing-$i.jpg',
              takenAt: i,
              lat: 50.7217,
              lng: 10.4483,
              distanceM: i * 100.0,
            ),
        ],
      );

      expect(find.text('Photos (3)'), findsOneWidget);
      expect(find.byType(PhotoThumbnail), findsNWidgets(3));
      // The map pins are not asserted: flutter_map builds no markers at all on the headless
      // test host, including the start and finish dots that were there before photos.
    });

    testWidgets('a run with no photos shows no photo section', (tester) async {
      await pumpDetail(tester, run(id: '4', title: 'Plain run'));
      expect(find.textContaining('Photos'), findsNothing);
    });

    testWidgets('an unclosed run shows the path and no area', (tester) async {
      await pumpDetail(tester, run(id: '2', title: 'Aborted run'));

      expect(find.text('No loop closed — nothing claimed'), findsOneWidget);
      expect(find.text('1253 m'), findsOneWidget);
    });

    testWidgets('a claimed run leads with the area', (tester) async {
      await pumpDetail(
        tester,
        run(id: '1', title: 'Morning run', areaM2: 32400),
      );

      expect(find.text('0.032 km² claimed'), findsOneWidget);
    });

    testWidgets('an unverified claim is flagged', (tester) async {
      await pumpDetail(
        tester,
        run(id: '3', title: 'Driven', areaM2: 32400, verified: false),
      );

      expect(
        find.text('Unverified — excluded from the leaderboard'),
        findsOneWidget,
      );
    });

    testWidgets('an unclosed run is never flagged unverified', (tester) async {
      // There is no ground to exclude, so the warning would be noise.
      await pumpDetail(tester, run(id: '4', title: 'Aborted', verified: false));

      expect(
        find.text('Unverified — excluded from the leaderboard'),
        findsNothing,
      );
    });

    testWidgets('a run with an unusable path says so instead of drawing nothing', (
      tester,
    ) async {
      await pumpDetail(tester, run(id: '5', title: 'Corrupt', encodedPath: ''));

      expect(find.text('No path recorded for this run.'), findsOneWidget);
    });

    testWidgets('a stored profile is redrawn as a chart', (tester) async {
      await pumpDetail(
        tester,
        run(
          id: '6',
          title: 'Hilly',
          encodedElevation: '0,300;250,340;500,315',
        ),
      );

      expect(find.byType(ElevationChart), findsOneWidget);
      expect(find.text('340 m'), findsOneWidget, reason: 'the summit label');
      expect(find.text('300 m'), findsOneWidget, reason: 'the low point');
    });

    testWidgets('a run recorded before the chart existed shows none', (
      tester,
    ) async {
      // Every row migrated from v2 carries an empty profile. That has to read as "nothing to
      // draw", not as a broken chart.
      await pumpDetail(tester, run(id: '7', title: 'Old run'));

      expect(find.byType(ElevationChart), findsNothing);
      expect(find.text('Elevation'), findsNothing);
    });
  });
}
