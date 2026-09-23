import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'tracking_controller.dart';

/// `m:ss`, growing to `h:mm:ss` past the hour — what a stopwatch shows.
String formatElapsed(Duration d) {
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$minutes:$seconds';
  }
  return '${d.inMinutes}:$seconds';
}

/// Metres until a kilometre, then kilometres to two places.
String formatDistance(double metres) => metres >= 1000
    ? '${(metres / 1000).toStringAsFixed(2)} km'
    : '${metres.round()} m';

/// Below this the pace would read in the tens of minutes per kilometre — GPS jitter while
/// standing at a crossing, not a number to put in front of a runner.
const double _minPaceSpeedMs = 0.5;

/// Minutes per kilometre from a speed in m/s, or a dash when there is no pace to speak of.
String formatPace(double speedMs) {
  if (speedMs < _minPaceSpeedMs) return '—';
  final secondsPerKm = (1000 / speedMs).round();
  final minutes = secondsPerKm ~/ 60;
  final seconds = (secondsPerKm % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds /km';
}

/// The live counter: everything measured about the run in progress, at a glance.
///
/// Meant to sit on the map while running and nowhere else — the summary screen owns the
/// numbers once the run has ended. Elapsed time ticks on this widget's own clock rather than
/// through the controller, so a second passing does not rebuild the map.
class RunStatsHud extends StatefulWidget {
  const RunStatsHud({required this.state, super.key});

  final TrackingState state;

  @override
  State<RunStatsHud> createState() => _RunStatsHudState();
}

class _RunStatsHudState extends State<RunStatsHud> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final fix = state.currentFix;
    final startedAt = state.startedAt;
    final elapsed = startedAt == null
        ? Duration.zero
        // `clock` rather than `DateTime.now()` so a widget test's fake clock drives the tick.
        : clock.now().difference(startedAt);

    final counters = <_Counter>[
      _Counter('Time', formatElapsed(elapsed)),
      _Counter('Distance', formatDistance(state.distanceM)),
      _Counter('Pace', formatPace(fix?.speedMs ?? 0)),
      _Counter('Closure', '${(state.closureProgress * 100).round()}%'),

      // Each of these appears only when something is actually measuring it.
      if (state.altitudeM != null)
        _Counter('Altitude', '${state.altitudeM!.round()} m'),
      if (state.availability.barometer)
        _Counter('Climb', '${state.elevationGainM.round()} m'),
      if (state.availability.pedometer) _Counter('Steps', '${state.steps}'),
      if (fix != null) _Counter('GPS', '±${fix.accuracyM.round()} m'),
    ];

    return Material(
      color: theme.colorScheme.inverseSurface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(14),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LiveDot(color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  state.status,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                for (final c in counters)
                  _CounterTile(label: c.label, value: c.value),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter {
  const _Counter(this.label, this.value);
  final String label;
  final String value;
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onDark = theme.colorScheme.onInverseSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            color: onDark.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: onDark,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// A recording light. Says "this is live" without a word, and pulses so that a paused screen
/// is distinguishable from a stalled one at a glance.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    // Never to nothing: a dot that disappears reads as a fault rather than a heartbeat.
    opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    ),
    child: Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}
