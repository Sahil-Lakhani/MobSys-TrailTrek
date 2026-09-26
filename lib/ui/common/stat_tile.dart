import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// One labelled number: a small uppercase caption over a big figure.
///
/// The one stat widget every screen uses, so a distance on the map, in the live counter and on
/// the summary all read as the same thing.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.size = 20,
    this.valueColor = AppColors.text,
    this.detail,
    super.key,
  });

  final String label;
  final String value;

  /// Font size of the figure.
  final double size;
  final Color valueColor;

  /// An optional muted line under the figure.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10.5,
            letterSpacing: 1.1,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: AppTheme.number(size, color: valueColor),
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(
            detail!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Stats laid out in even columns inside a card, wrapping to new rows on narrow screens.
class StatGrid extends StatelessWidget {
  const StatGrid({required this.children, this.columns = 3, super.key});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// A small rounded label: status, warnings, badges.
class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    this.icon,
    this.color = AppColors.surfaceHigh,
    this.foreground = AppColors.text,
    this.leading,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color foreground;

  /// Something other than an icon at the start, such as a live dot.
  final Widget? leading;

  /// Warning-coloured, for claims that will not count.
  const Pill.warning({required this.label, super.key})
    : icon = Icons.info_outline_rounded,
      color = const Color(0x26FFB547),
      foreground = AppColors.warning,
      leading = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
