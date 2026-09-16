import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../summary/run_summary_screen.dart';
import '../tracking/tracking_controller.dart';
import '../tracking/tracking_map.dart';
import 'leaderboard_sheet.dart';

/// The map, the board, and the control that starts a run.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingControllerProvider);
    final controller = ref.read(trackingControllerProvider.notifier);

    // A closed loop owes the runner a decision. Pushed on the root navigator so it covers the
    // tab bar too — wandering off to Treks with an uncommitted claim behind you is not one of
    // the two answers.
    ref.listen(
      trackingControllerProvider.select((s) => s.pendingRun),
      (previous, pending) {
        if (previous != null || pending == null) return;
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => RunSummaryScreen(run: pending),
          ),
        );
      },
    );

    return Scaffold(
      body: Stack(
        children: [
          const TrackingMap(),
          const LeaderboardSheet(),
          Positioned(
            right: 16,
            bottom: 108,
            child: GestureDetector(
              // Replay is reachable but not advertised: it is the indoor test harness, not a
              // feature. Debugging polygon clipping by walking around a car park is not a
              // workable loop, so it has to stay one gesture away.
              onLongPress: state.running
                  ? null
                  : () {
                      controller.startReplay();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Replaying the recorded loop at 10x'),
                        ),
                      );
                    },
              child: FloatingActionButton.extended(
                onPressed: state.running ? controller.stop : controller.start,
                icon: Icon(state.running ? Icons.stop : Icons.play_arrow),
                label: Text(state.running ? 'Stop' : 'Start run'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
