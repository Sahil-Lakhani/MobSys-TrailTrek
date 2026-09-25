import 'package:flutter/material.dart';

import '../../geo/loop_detector.dart';

/// Ends a run, but only after being held down for [holdDuration].
///
/// A tap is too easy to make by accident mid-stride, and ending a run is not undoable — the
/// track stops recording. The button also says, before anyone commits, whether ending here
/// would claim ground, so the runner can decide to carry on back to the start instead.
class HoldToEndButton extends StatefulWidget {
  const HoldToEndButton({
    required this.canClaim,
    required this.distanceToStartM,
    required this.onEnd,
    this.onReleasedEarly,
    super.key,
  });

  static const Duration holdDuration = Duration(milliseconds: 1500);

  /// Whether ending now would close the loop and claim the ground inside it.
  final bool canClaim;

  /// How far the runner is from the start, shown when ending would not claim.
  final double distanceToStartM;

  final VoidCallback onEnd;

  /// Let go before the hold completed — a chance to explain that it has to be held.
  final VoidCallback? onReleasedEarly;

  @override
  State<HoldToEndButton> createState() => _HoldToEndButtonState();
}

class _HoldToEndButtonState extends State<HoldToEndButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: HoldToEndButton.holdDuration,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _hold.value = 0;
      widget.onEnd();
    }
  }

  void _press() => _hold.forward();

  void _release() {
    // Keyed to direction, not value: a tap let go before the first frame still reads 0, and
    // skipping it then would leave the fill running on to end the run by itself.
    if (_hold.status != AnimationStatus.forward) return;
    _hold.reverse();
    widget.onReleasedEarly?.call();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = widget.canClaim ? scheme.primary : scheme.inverseSurface;
    final foreground = widget.canClaim
        ? scheme.onPrimary
        : scheme.onInverseSurface;

    final subtitle = widget.canClaim
        ? 'Area will be claimed'
        : 'No claim · ${widget.distanceToStartM.round()} m from start '
              '(need ${LoopDetector.closeRadiusM.round()} m)';

    return Semantics(
      button: true,
      label: 'Hold to end run. $subtitle',
      // A screen reader cannot hold; its long-press action is the equivalent deliberate act.
      onLongPress: widget.onEnd,
      child: Listener(
        onPointerDown: (_) => _press(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: Material(
          color: background,
          elevation: 6,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // The fill sweeps across as the button is held: progress you can feel.
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _hold.value,
                    child: ColoredBox(color: foreground.withValues(alpha: 0.28)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      widget.canClaim ? Icons.flag : Icons.stop,
                      color: foreground,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hold to end run',
                            style: TextStyle(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(color: foreground, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
