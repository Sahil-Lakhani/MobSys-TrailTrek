import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'glass_panel.dart';

/// The layout every "one thing, on a map" screen shares: the map up top with rounded lower
/// corners and a floating back button, and the numbers scrolling underneath.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    required this.title,
    required this.map,
    required this.children,
    this.eyebrow,
    super.key,
  });

  final String title;

  /// Small caption above the title, such as a date or a trail type.
  final String? eyebrow;
  final Widget map;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final mapHeight = MediaQuery.sizeOf(context).height * 0.42;
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.only(bottom: padding.bottom + 24),
          children: [
            SizedBox(
              height: mapHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                    child: map,
                  ),
                  // Keeps the status bar legible over a pale map.
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: padding.top + 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.bg.withValues(alpha: 0.5),
                              AppColors.bg.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: padding.top + 8,
                    child: GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                // Stretch, so every card spans the width rather than hugging its content.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (eyebrow != null) ...[
                    Text(
                      eyebrow!.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(title, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 18),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled card section inside a detail screen.
class DetailSection extends StatelessWidget {
  const DetailSection({required this.child, this.title, super.key});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Map pin for a track's start or finish: a coloured dot in a white ring.
class TrackPin extends StatelessWidget {
  const TrackPin({required this.color, this.icon, super.key});

  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
      ),
      child: icon == null
          ? null
          : Icon(icon, size: 12, color: AppColors.onAccent),
    );
  }
}
