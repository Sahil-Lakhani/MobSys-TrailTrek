import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/model/models.dart';
import '../../data/providers.dart';
import '../summary/run_summary_screen.dart' show formatArea;
import '../tracking/tracking_map.dart' show parseHex;

/// Who holds what, ranked by area.
///
/// Its own tab, so the home screen can be the map and nothing else. The board is a stream, so
/// a claim saved on Home has already moved you by the time you look here.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: board.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Leaderboard unavailable: $error'),
          ),
        ),
        data: (entries) => entries.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No ground claimed yet. Run a loop and it lands here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                children: [
                  _YourStanding(entries: entries),
                  for (final entry in entries) _LeaderRow(entry: entry),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}

/// Your own rank and area, pinned above the table: the one row you always want.
class _YourStanding extends StatelessWidget {
  const _YourStanding({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final you = entries.where((e) => e.isYou);
    final text = you.isEmpty
        ? 'You hold nothing yet'
        : '#${you.first.rank} · ${formatArea(you.first.totalAreaM2)}';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your standing', style: theme.textTheme.titleMedium),
            Text(text, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = parseHex(entry.colorHex, theme.colorScheme.primary);

    return ListTile(
      leading: SizedBox(
        width: 44,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '${entry.rank}',
                style: theme.textTheme.labelLarge,
              ),
            ),
            CircleAvatar(radius: 8, backgroundColor: colour),
          ],
        ),
      ),
      title: Text(
        entry.isYou ? '${entry.ownerName} (you)' : entry.ownerName,
        style: entry.isYou
            ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
            : theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        '${entry.territoryCount} '
        '${entry.territoryCount == 1 ? "plot" : "plots"}',
      ),
      trailing: Text(
        formatArea(entry.totalAreaM2),
        style: theme.textTheme.titleMedium,
      ),
    );
  }
}
