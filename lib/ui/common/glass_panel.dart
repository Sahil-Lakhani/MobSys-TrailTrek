import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.shape = BoxShape.rectangle,
    this.opacity = 0.82,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final BoxShape shape;
  final double opacity;

  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = shape == BoxShape.circle
        ? null
        : BorderRadius.circular(radius);

    final panel = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: opacity),
          shape: shape,
          borderRadius: borderRadius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: shape == BoxShape.circle
          ? ClipOval(child: panel)
          : ClipRRect(borderRadius: borderRadius!, child: panel),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 48,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GlassPanel(
        shape: BoxShape.circle,
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                icon,
                size: 22,
                color: active ? AppColors.accent : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
