import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/model/models.dart';
import '../../data/providers.dart';
import '../common/empty_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tracking/tracking_map.dart' show parseHex;

String formatArea(double m2) =>
    m2 >= 10000 ? '${(m2 / 10000).toStringAsFixed(2)} ha' : '${m2.round()} m²';

/// Who holds what.
///
/// Its own tab rather than a sheet over the map: the map is for running, and a board that is
/// always half-open eats the ground you are trying to see.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(leaderboardProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
          children: [
            Text('Leaderboard', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Ranked by verified ground held',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            ...board.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, _) => [
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Leaderboard unavailable',
                    body: '$error',
                  ),
                ),
              ],
              data: (entries) => entries.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: EmptyState(
                          icon: Icons.emoji_events_rounded,
                          title: 'Nobody holds anything yet',
                          body: 'No ground claimed yet. Run a loop and it lands here.',
                        ),
                      ),
                    ]
                  : [
                      _Standing(entries: entries),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 10),
                        child: Text(
                          'RANKING',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              for (final entry in entries)
                                _LeaderRow(entry: entry),
                            ],
                          ),
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Your own place on the board: the one row you always want, lifted to the top.
class _Standing extends StatelessWidget {
  const _Standing({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final you = entries.where((e) => e.isYou).firstOrNull;
    final leader = entries.first;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF26300F), AppColors.surface],
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: you == null
          ? Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  color: AppColors.accent,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You hold nothing yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Close a verified loop to get on the board.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR STANDING',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '#${you.rank} · ${formatArea(you.totalAreaM2)}',
                        style: AppTheme.number(30),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        you.rank == 1
                            ? 'You lead the board.'
                            : '${formatArea(leader.totalAreaM2 - you.totalAreaM2)} '
                                  'behind ${leader.ownerName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.emoji_events_rounded,
                  size: 44,
                  color: you.rank == 1 ? AppColors.gold : AppColors.outline,
                ),
              ],
            ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.entry});

  final LeaderboardEntry entry;

  static Color? _podium(int rank) => switch (rank) {
    1 => AppColors.gold,
    2 => AppColors.silver,
    3 => AppColors.bronze,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = parseHex(entry.colorHex, AppColors.accent);
    final podium = _podium(entry.rank);
    final initial = entry.ownerName.trim().isEmpty
        ? '?'
        : entry.ownerName.trim()[0].toUpperCase();

    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        // Your own row lifts out of the list: it is the one you are scanning for.
        color: entry.isYou
            ? AppColors.accent.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: entry.isYou
            ? Border.all(color: AppColors.accent.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              style: AppTheme.number(16, color: podium ?? AppColors.textMuted),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: colour, width: 2),
            ),
            child: Text(initial, style: AppTheme.number(14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isYou ? '${entry.ownerName} (you)' : entry.ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: entry.isYou ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                Text(
                  '${entry.territoryCount} '
                  '${entry.territoryCount == 1 ? "plot" : "plots"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatArea(entry.totalAreaM2),
            style: AppTheme.number(
              17,
              color: entry.isYou ? AppColors.accent : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
