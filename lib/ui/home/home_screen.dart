import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../summary/run_summary_screen.dart';
import '../tracking/hold_to_end_button.dart';
import '../tracking/run_stats_hud.dart';
import '../tracking/tracking_controller.dart';
import '../tracking/tracking_map.dart';

/// The map, and the control that starts and ends a run. The leaderboard has its own tab.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingControllerProvider);
    final controller = ref.read(trackingControllerProvider.notifier);

    // An ended run owes the runner a decision. Pushed on the root navigator so it covers the
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

          // While running: the live counter, and under it the only way to end the run.
          if (state.running)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(child: RunStatsHud(state: state)),
                      // Photos are kept as files on the device; a browser has nowhere to
                      // put them, so the web build simply has no camera button.
                      if (!kIsWeb) ...[
                        const SizedBox(width: 12),
                        _CameraButton(
                          count: state.photos.length,
                          onPressed: () => _takePhoto(context, controller),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  HoldToEndButton(
                    canClaim: state.canClaim,
                    distanceToStartM: state.distanceToStartM,
                    onEnd: controller.stop,
                    onReleasedEarly: () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Keep holding to end the run'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                    },
                  ),
                ],
              ),
            )
          else
            Positioned(
              right: 16,
              bottom: 16,
              child: GestureDetector(
                // Replay is reachable but not advertised: it is the indoor test harness, not
                // a feature. Debugging polygon clipping by walking around a car park is not a
                // workable loop, so it has to stay one gesture away.
                onLongPress: () => _chooseReplay(context, controller),
                child: FloatingActionButton.extended(
                  onPressed: controller.start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start run'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Opens the system camera and files whatever comes back against the run in progress.
  ///
  /// Tracking carries on while the camera is open: the location service runs in the
  /// foreground, and the replay runs on timers that do not stop for it.
  Future<void> _takePhoto(
    BuildContext context,
    TrackingController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        // A run photo is for looking back at, not for printing. This keeps each one to a few
        // hundred kilobytes instead of several megabytes.
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (shot == null) return; // Backed out of the camera.
      await controller.addPhoto(shot.path);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Photo added to this run'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not take a photo: $error')),
      );
    }
  }

  /// Picks which recorded route the replay harness plays.
  Future<void> _chooseReplay(
    BuildContext context,
    TrackingController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showModalBottomSheet<MapEntry<String, String>>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Replay a recorded route')),
            for (final route in replayRoutes.entries)
              ListTile(
                leading: const Icon(Icons.route),
                title: Text(route.key),
                onTap: () => Navigator.pop(context, route),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;

    await controller.startReplay(asset: chosen.value);
    messenger.showSnackBar(
      SnackBar(content: Text('Replaying "${chosen.key}" at 10x')),
    );
  }
}

/// Takes a photo mid-run, and shows how many this run has so far.
class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: FloatingActionButton(
        heroTag: 'camera',
        tooltip: 'Take a photo',
        onPressed: onPressed,
        child: const Icon(Icons.photo_camera),
      ),
    );
  }
}
