import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../summary/run_summary_screen.dart';
import '../tracking/run_stats_hud.dart';
import '../tracking/tracking_controller.dart';
import '../tracking/tracking_map.dart';
import 'leaderboard_sheet.dart';

/// The map, the board, and the control that starts a run.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// How far the leaderboard is dragged open, as a fraction of the screen.
  ///
  /// A notifier rather than `setState` so a drag repaints the controls that sit over the sheet
  /// without rebuilding the map underneath them.
  final ValueNotifier<double> _sheetExtent = ValueNotifier<double>(0);

  /// Roughly an extended FAB, which is what the fade is measured against.
  static const double _controlHeight = 56;

  @override
  void dispose() {
    _sheetExtent.dispose();
    super.dispose();
  }

  /// Fades the map controls out as the board is dragged up over them.
  ///
  /// Without this the Start button floats in the middle of the opened sheet, looking like a
  /// control that belongs to the leaderboard. Someone reading the board is not starting a run.
  Widget _hideUnderSheet({
    required double screenHeight,
    required double controlsBottom,
    required Widget child,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _sheetExtent,
      child: child,
      builder: (context, extent, child) {
        // Keyed to where the sheet edge actually is, not to how far it has been dragged. A
        // board with two rows barely moves and never reaches these controls, so it should not
        // dim them — a half-transparent button nothing is covering just looks broken.
        final sheetTop = extent * screenHeight;
        final overlap = sheetTop - controlsBottom;
        final opacity = (1 - (overlap / _controlHeight)).clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: opacity < 0.05,
          child: Opacity(opacity: opacity, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingControllerProvider);
    final controller = ref.read(trackingControllerProvider.notifier);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final collapsed = LeaderboardMetrics.collapsedFraction(screenHeight);
    // Sit clear of the collapsed board rather than at a fixed offset, which stops matching the
    // moment the board's height depends on how many players it holds.
    final controlsBottom = collapsed * screenHeight + 16;

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
      body: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          _sheetExtent.value = notification.extent;
          // Let it keep bubbling; nothing above depends on it, but swallowing a notification
          // other people may later listen for is a trap worth not setting.
          return false;
        },
        child: Stack(
          children: [
            const TrackingMap(),
            const LeaderboardSheet(),

            // The live counter. Bottom-left, opposite the Stop control and clear of the
            // leaderboard handle, so a glance down mid-stride lands on it.
            if (state.running)
              Positioned(
                left: 16,
                right: 140,
                bottom: controlsBottom,
                child: _hideUnderSheet(
                  screenHeight: screenHeight,
                  controlsBottom: controlsBottom,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: RunStatsHud(state: state),
                  ),
                ),
              ),
            Positioned(
              right: 16,
              bottom: controlsBottom,
              child: _hideUnderSheet(
                screenHeight: screenHeight,
                controlsBottom: controlsBottom,
                child: GestureDetector(
                  // Replay is reachable but not advertised: it is the indoor test harness, not
                  // a feature. Debugging polygon clipping by walking around a car park is not a
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
                    onPressed: state.running
                        ? controller.stop
                        : controller.start,
                    icon: Icon(state.running ? Icons.stop : Icons.play_arrow),
                    label: Text(state.running ? 'Stop' : 'Start run'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
