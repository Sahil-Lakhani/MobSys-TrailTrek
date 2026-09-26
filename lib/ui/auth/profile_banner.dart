import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tracking/tracking_map.dart' show parseHex;

/// The top of a profile: a banner in the player's colour with the avatar overlapping its lower
/// edge, and an optional control in the top-right corner.
///
/// Shared by the profile and the editor, so what you edit looks exactly like what others see.
class ProfileBanner extends StatelessWidget {
  const ProfileBanner({
    required this.colorHex,
    required this.avatar,
    this.action,
    this.topInset = 0,
    super.key,
  });

  final String colorHex;
  final Widget avatar;

  /// Sits in the banner's top-right corner — the profile's Edit button.
  final Widget? action;

  /// Extra banner height for a status bar drawn over it.
  final double topInset;

  static const double _bannerHeight = 120;

  /// How far the avatar hangs below the banner.
  static const double _overhang = 52;

  @override
  Widget build(BuildContext context) {
    final colour = parseHex(colorHex, AppColors.accent);
    final height = topInset + _bannerHeight;

    return SizedBox(
      height: height + _overhang,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(colour, AppColors.bg, 0.15)!,
                    Color.lerp(colour, AppColors.bg, 0.65)!,
                  ],
                ),
              ),
              child: CustomPaint(painter: _ContourPainter(colour)),
            ),
          ),
          if (action != null)
            Positioned(top: topInset + 12, right: 12, child: action!),
          Positioned(left: 16, bottom: 0, child: avatar),
        ],
      ),
    );
  }
}

/// A ring in the page colour around the avatar, so it reads as cut out of the banner.
class ProfileAvatarRing extends StatelessWidget {
  const ProfileAvatarRing({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

/// Faint elevation lines across the banner: a map, abstracted, in the player's colour.
class _ContourPainter extends CustomPainter {
  const _ContourPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.82, size.height * 0.3);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 1; i <= 9; i++) {
      final r = i * size.width * 0.07;
      line.color = Colors.white.withValues(alpha: 0.13 * (1 - i / 11));
      final path = Path();
      const steps = 64;
      for (var s = 0; s <= steps; s++) {
        final a = s / steps * 2 * math.pi;
        final wobble = 1 + 0.08 * math.sin(a * 3 + i * 0.7) + 0.05 * math.cos(a * 5 - i);
        final p = centre + Offset(math.cos(a), math.sin(a)) * r * wobble;
        s == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_ContourPainter oldDelegate) => oldDelegate.colour != colour;
}
