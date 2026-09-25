import 'package:claimtrek/ui/tracking/hold_to_end_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int ended;
  late int releasedEarly;

  setUp(() {
    ended = 0;
    releasedEarly = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    bool canClaim = true,
    double distanceToStartM = 12,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: HoldToEndButton(
            canClaim: canClaim,
            distanceToStartM: distanceToStartM,
            onEnd: () => ended++,
            onReleasedEarly: () => releasedEarly++,
          ),
        ),
      ),
    ),
  );

  testWidgets('a tap does not end the run', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Hold to end run'));
    await tester.pumpAndSettle();

    expect(ended, 0, reason: 'a stray tap mid-stride must not end the run');
    expect(releasedEarly, 1, reason: 'the runner is told it has to be held');
  });

  testWidgets('letting go halfway does not end the run', (tester) async {
    await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold to end run')),
    );
    await tester.pump();
    await tester.pump(HoldToEndButton.holdDuration ~/ 2);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(ended, 0);
  });

  testWidgets('holding for the full duration ends the run once', (tester) async {
    await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold to end run')),
    );
    // The first frame starts the animation clock; the hold is measured from there.
    await tester.pump();
    await tester.pump(HoldToEndButton.holdDuration);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(ended, 1);
    expect(releasedEarly, 0);
  });

  testWidgets('says whether ending here claims ground', (tester) async {
    await pump(tester);
    expect(find.text('Area will be claimed'), findsOneWidget);

    await pump(tester, canClaim: false, distanceToStartM: 212.4);
    expect(find.text('No claim · 212 m from start (need 69 m)'), findsOneWidget);
  });
}
