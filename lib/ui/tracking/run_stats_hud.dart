import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../common/glass_panel.dart';
import '../common/stat_tile.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
    final closure = state.closureProgress.clamp(0.0, 1.0);

    // Each of these appears only when something is actually measuring it.
    final secondary = <Widget>[
      StatTile(label: 'Pace', value: formatPace(fix?.speedMs ?? 0), size: 16),
      if (state.altitudeM != null)
        StatTile(
          label: 'Altitude',
          value: '${state.altitudeM!.round()} m',
          size: 16,
        ),
      if (state.availability.barometer)
        StatTile(
          label: 'Climb',
          value: '${state.elevationGainM.round()} m',
          size: 16,
        ),
      if (state.availability.pedometer)
        StatTile(label: 'Steps', value: '${state.steps}', size: 16),
      if (fix != null)
        StatTile(label: 'GPS', value: '±${fix.accuracyM.round()} m', size: 16),
    ];

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(
                label: 'REC',
                color: AppColors.danger.withValues(alpha: 0.16),
                foreground: AppColors.danger,
                leading: const _LiveDot(color: AppColors.danger),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatTile(
                  label: 'Time',
                  value: formatElapsed(elapsed),
                  size: 34,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Distance',
                  value: formatDistance(state.distanceM),
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Closure is the whole game — how near the loop is to shutting — so it gets a bar,
          // not just a number.
          Row(
            children: [
              Text(
                'CLOSURE',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: closure),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      color: AppColors.accent,
                      backgroundColor: AppColors.outline,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(state.closureProgress * 100).round()}%',
                style: AppTheme.number(15, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 22, runSpacing: 10, children: secondary),
        ],
      ),
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

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
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
    opacity: Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
    child: Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}
