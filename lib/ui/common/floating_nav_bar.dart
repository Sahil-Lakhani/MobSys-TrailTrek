import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// One tab on the [FloatingNavBar].
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A raised tab bar with a single indicator that springs between tabs.
///
/// One indicator that travels, rather than a pill per tab that fades in and out: the eye
/// follows something moving from here to there, where a swap between two static states reads
/// as a flicker. The tabs themselves never change width, so nothing else on the bar shifts.
class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// The bar itself, without its outer margin.
  static const double height = 68;

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar>
    with SingleTickerProviderStateMixin {
  /// Slightly under-damped: the indicator overshoots a touch and settles, which is what
  /// makes it feel physical rather than tweened.
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 30,
  );

  /// The indicator's position, in tab units: 0 is the first tab, 1.5 is halfway between the
  /// second and third. Unbounded because a spring overshoots its target.
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.currentIndex.toDouble(),
  );

  @override
  void didUpdateWidget(FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // Start from wherever the indicator is right now, with the speed it already has, so a
      // second tap mid-flight redirects it smoothly instead of snapping.
      _position.animateWith(
        SpringSimulation(
          _spring,
          _position.value,
          widget.currentIndex.toDouble(),
          _position.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final count = widget.destinations.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 10),
      child: Container(
        height: FloatingNavBar.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          // Lighter at the top edge, as if lit from above: the cue that makes a flat dark
          // shape read as raised.
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF262C35), Color(0xFF181C22)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          // Spread around the bar rather than dropped below it, so it lifts off whatever is
          // behind it without leaving a dark smear at the bottom of the screen.
          boxShadow: const [
            BoxShadow(
              color: Color(0x73000000),
              blurRadius: 28,
              spreadRadius: -2,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const inset = 6.0;
            final slot = (constraints.maxWidth - inset * 2) / count;

            return AnimatedBuilder(
              animation: _position,
              builder: (context, _) {
                final pos = _position.value;
                // Stretch with speed: the indicator smears a little in flight and snaps back
                // to shape as it lands.
                final stretch = (_position.velocity.abs() * 5).clamp(
                  0.0,
                  slot * 0.4,
                );
                final indicatorWidth = slot - 8 + stretch;
                final left = inset + pos * slot + (slot - indicatorWidth) / 2;

                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: inset,
                      bottom: inset,
                      width: indicatorWidth,
                      child: const _Indicator(),
                    ),
                    Positioned.fill(
                      left: inset,
                      right: inset,
                      child: Row(
                        children: [
                          for (var i = 0; i < count; i++)
                            Expanded(
                              child: _Tab(
                                destination: widget.destinations[i],
                                // 1 when the indicator sits squarely on this tab, fading to
                                // 0 as it moves a full tab away.
                                activeness: (1 - (pos - i).abs()).clamp(
                                  0.0,
                                  1.0,
                                ),
                                selected: i == widget.currentIndex,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  widget.onSelected(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD6FF4F), AppColors.accent],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.destination,
    required this.activeness,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;

  /// How much of the indicator is under this tab, 0 to 1.
  final double activeness;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Colour follows the indicator continuously, so icons darken as it slides under them
    // rather than flipping when the tap lands.
    final colour = Color.lerp(
      AppColors.textMuted,
      AppColors.onAccent,
      Curves.easeOut.transform(activeness),
    )!;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A small bounce when a tab becomes the selected one.
            TweenAnimationBuilder<double>(
              key: ValueKey(selected),
              tween: Tween(begin: selected ? 0.8 : 1, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Icon(
                activeness > 0.5 ? destination.selectedIcon : destination.icon,
                size: 24,
                color: colour,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 11.5,
                fontWeight: activeness > 0.5
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: colour,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
