import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/location_access.dart';
import '../auth/account_action.dart';
import '../common/glass_panel.dart';
import '../summary/run_summary_screen.dart';
import '../theme/app_colors.dart';
import '../tracking/location_access_notice.dart';
import '../tracking/run_stats_hud.dart';
import '../tracking/tracking_controller.dart';
import '../tracking/tracking_map.dart';

/// The map and the control that starts a run.
///
/// Nothing else sits over the map: the leaderboard has its own tab, so the ground you are
/// running on is never hidden behind the score of it.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<TrackingMapState> _mapKey = GlobalKey<TrackingMapState>();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingControllerProvider);
    final controller = ref.read(trackingControllerProvider.notifier);
    final padding = MediaQuery.paddingOf(context);

    // A closed loop owes the runner a decision. Pushed on the root navigator so it covers the
    // tab bar too — wandering off to Treks with an uncommitted claim behind you is not one of
    // the two answers.
    ref.listen(trackingControllerProvider.select((s) => s.pendingRun), (
      previous,
      pending,
    ) {
      if (previous != null || pending == null) return;
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: (_) => RunSummaryScreen(run: pending)),
      );
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The status bar sits on the dark scrim below, so its icons are light.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            TrackingMap(key: _mapKey),

            // A soft shade behind the status bar and the top controls, so the clock and the
            // chrome stay legible over a pale map.
            IgnorePointer(
              child: Container(
                height: padding.top + 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bg.withValues(alpha: 0.55),
                      AppColors.bg.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              left: 16,
              right: 16,
              top: padding.top + 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [_BrandChip(), Spacer(), AccountAction()],
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    // While running, the live counter takes this slot over everything
                    // else: up here it leaves the middle of the map — where the camera
                    // keeps the runner — clear, and mid-run the numbers are what matter.
                    child: state.running
                        ? RunStatsHud(state: state)
                        : state.access != LocationAccess.granted
                        ? LocationAccessNotice(access: state.access)
                        // Hugs its stats rather than spanning the screen; every pixel it
                        // does not need is map the runner can see.
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: IntrinsicWidth(
                              child: MapStatusStrip(state: state),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // `padding.bottom` already includes the floating tab bar (the shell extends its
            // body under it), so this sits just clear of the bar.
            Positioned(
              left: 16,
              right: 16,
              bottom: padding.bottom + 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(child: SizedBox()),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: state.running
                        ? _HoldToStopButton(
                            key: const ValueKey('stop'),
                            onStop: controller.stop,
                          )
                        : _StartButton(
                            key: const ValueKey('start'),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              controller.start();
                            },
                            // Replay is reachable but not advertised: it is the indoor test
                            // harness, not a feature. Debugging polygon clipping by walking
                            // around a car park is not a workable loop, so it has to stay
                            // one gesture away.
                            onLongPress: () {
                              HapticFeedback.heavyImpact();
                              controller.startReplay();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Replaying the recorded loop at 10x',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: GlassIconButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Centre on me',
                        onPressed: () => _mapKey.currentState?.recentre(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's mark, top left over the map.
class _BrandChip extends StatelessWidget {
  const _BrandChip();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 100,
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_rounded,
              size: 20,
              color: AppColors.onAccent,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'ClaimTrek',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.3,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

const double _buttonSize = 84;

/// The round face shared by Start and Stop: a coloured disc with an icon over a label.
class _RoundFace extends StatelessWidget {
  const _RoundFace({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _buttonSize,
      height: _buttonSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.bg, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 34, color: foreground),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.4,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Starting is one tap: nothing is lost by starting by accident.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.onPressed,
    required this.onLongPress,
    super.key,
  });

  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start run',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          onLongPress: onLongPress,
          child: const _RoundFace(
            color: AppColors.accent,
            foreground: AppColors.onAccent,
            icon: Icons.play_arrow_rounded,
            label: 'START',
          ),
        ),
      ),
    );
  }
}

/// Stopping has to be held, not tapped.
///
/// A stop ends the run and closes the chance of the loop; a phone bumped in a pocket or a
/// thumb brushing the screen mid-stride must not do that. A ring fills while the button is
/// held, and letting go early unwinds it. A quick tap only explains what to do.
class _HoldToStopButton extends StatefulWidget {
  const _HoldToStopButton({required this.onStop, super.key});

  final VoidCallback onStop;

  @override
  State<_HoldToStopButton> createState() => _HoldToStopButtonState();
}

class _HoldToStopButtonState extends State<_HoldToStopButton>
    with SingleTickerProviderStateMixin {
  static const Duration _holdFor = Duration(milliseconds: 1200);

  late final AnimationController _hold =
      AnimationController(vsync: this, duration: _holdFor)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && !_fired) {
            _fired = true;
            HapticFeedback.heavyImpact();
            widget.onStop();
          }
        });

  bool _fired = false;
  bool _showHint = false;
  DateTime? _pressedAt;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _down() {
    if (_fired) return;
    _pressedAt = DateTime.now();
    HapticFeedback.selectionClick();
    setState(() => _showHint = false);
    _hold.forward();
  }

  void _up() {
    if (_fired) return;
    final pressedAt = _pressedAt;
    _pressedAt = null;
    _hold.animateBack(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    // Let go almost at once: that was a tap, and a tap deserves an answer rather than
    // silence.
    if (pressedAt != null &&
        DateTime.now().difference(pressedAt) <
            const Duration(milliseconds: 350)) {
      setState(() => _showHint = true);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showHint = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = IgnorePointer(
      child: AnimatedOpacity(
        opacity: _showHint ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: const GlassPanel(
          radius: 100,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            'Hold to stop',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    // The hint floats above the button rather than taking layout space, so Stop sits exactly
    // where Start did.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Semantics(
          button: true,
          label: 'Hold to stop run',
          excludeSemantics: true,
          // A screen reader cannot hold, so its activation stops the run outright.
          onTap: widget.onStop,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _down(),
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) => _up(),
            child: AnimatedBuilder(
              animation: _hold,
              builder: (context, child) => Transform.scale(
                // Presses in slightly as it fills, so holding feels like pushing.
                scale: 1 - 0.06 * _hold.value,
                child: CustomPaint(
                  foregroundPainter: _RingPainter(progress: _hold.value),
                  child: child,
                ),
              ),
              child: const _RoundFace(
                color: AppColors.danger,
                foreground: Colors.white,
                icon: Icons.stop_rounded,
                label: 'HOLD',
              ),
            ),
          ),
        ),
        Positioned(
          bottom: _buttonSize + 12,
          left: -80,
          right: -80,
          child: Center(child: hint),
        ),
      ],
    );
  }
}

/// The fill ring around the stop button.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
