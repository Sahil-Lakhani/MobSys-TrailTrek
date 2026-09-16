import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/local/path_codec.dart';
import 'package:claimtrek/data/providers.dart';
import 'package:claimtrek/geo/lat_lng.dart';
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
      expect(find.text('3.24 ha'), findsOneWidget);
    });

    testWidgets('a run that closed no loop reads "no loop", not "0 m²"', (
      tester,
    ) async {
      // Claiming nothing because the shape never closed is a different thing from claiming an
      // area of nothing, and the list should not make it look like a failed claim.
      await pumpList(tester, [run(id: '2', title: 'Aborted run')]);

      expect(find.text('no loop'), findsOneWidget);
      expect(find.text('0 m²'), findsNothing);
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
    Future<void> pumpDetail(WidgetTester tester, Run value) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: RunDetailScreen(run: value)),
        ),
      );
      await tester.pump();
    }

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

      expect(find.text('3.24 ha claimed'), findsOneWidget);
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
  });
}
