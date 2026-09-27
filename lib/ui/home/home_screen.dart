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
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            TrackingMap(key: _mapKey),

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
                    child: state.running
                        ? RunStatsHud(state: state)
                        : state.access != LocationAccess.granted
                        ? LocationAccessNotice(access: state.access)
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
                            onLongPress: () {
                              HapticFeedback.heavyImpact();
                              _showTestRuns(context, controller);
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

void _showTestRuns(BuildContext context, TrackingController controller) {
  final messenger = ScaffoldMessenger.of(context);
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) {
      Widget option({
        required IconData icon,
        required String title,
        required String subtitle,
        required Future<void> Function() onTap,
      }) => ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.accent),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: () {
          Navigator.of(sheet).pop();
          onTap();
        },
      );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Test runs',
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Simulated at 10x through the real claim and save. Test runs are '
                  'marked unverified, so they never count on the leaderboard.',
                  style: Theme.of(sheet).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ),
              option(
                icon: Icons.add_location_alt_rounded,
                title: 'Capture new ground',
                subtitle: 'Runs a loop over empty ground near you',
                onTap: controller.startCaptureTest,
              ),
              option(
                icon: Icons.content_cut_rounded,
                title: 'Steal from a rival',
                subtitle: 'Runs over half of the nearest rival plot',
                onTap: () async {
                  final started = await controller.startStealTest();
                  if (!started) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No rival ground on the map to steal from',
                        ),
                      ),
                    );
                  }
                },
              ),
              option(
                icon: Icons.replay_rounded,
                title: 'Replay the recorded loop',
                subtitle: 'The bundled GPX track through the old town',
                onTap: controller.startReplay,
              ),
            ],
          ),
        ),
      );
    },
  );
}

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

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Semantics(
          button: true,
          label: 'Hold to stop run',
          excludeSemantics: true,
          onTap: widget.onStop,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _down(),
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) => _up(),
            child: AnimatedBuilder(
              animation: _hold,
              builder: (context, child) => Transform.scale(
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
