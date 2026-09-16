import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/model/models.dart';
import '../../data/providers.dart';
import '../tracking/tracking_map.dart' show parseHex;

String formatArea(double m2) => m2 >= 10000
    ? '${(m2 / 10000).toStringAsFixed(2)} ha'
    : '${m2.round()} m²';

/// Who holds what, dragged up over the map.
///
/// A sheet rather than its own tab: the board is the score of the thing you are looking at, and
/// having to leave the map to see whether you are winning breaks the loop.
class LeaderboardSheet extends ConsumerWidget {
  const LeaderboardSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(leaderboardProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.14,
      minChildSize: 0.14,
      maxChildSize: 0.62,
      snap: true,
      snapSizes: const [0.14, 0.62],
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: const [
              BoxShadow(blurRadius: 12, color: Colors.black26),
            ],
          ),
          child: board.when(
            loading: () => _shell(
              context,
              scrollController,
              const [Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))],
            ),
            error: (error, _) => _shell(context, scrollController, [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Leaderboard unavailable: $error'),
              ),
            ]),
            data: (entries) => _shell(
              context,
              scrollController,
              entries.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
                        child: Text(
                          'No ground claimed yet. Run a loop and it lands here.',
                        ),
                      ),
                    ]
                  : [
                      for (final entry in entries)
                        _LeaderRow(entry: entry),
                      const SizedBox(height: 24),
                    ],
              summary: entries.isEmpty ? null : _summaryOf(entries),
            ),
          ),
        );
      },
    );
  }

  /// What the collapsed sheet shows: your own standing, which is the one row you always want.
  static String _summaryOf(List<LeaderboardEntry> entries) {
    final you = entries.where((e) => e.isYou);
    if (you.isEmpty) return 'You hold nothing yet';
    final mine = you.first;
    return '#${mine.rank} · ${formatArea(mine.totalAreaM2)}';
  }

  Widget _shell(
    BuildContext context,
    ScrollController controller,
    List<Widget> children, {
    String? summary,
  }) {
    final theme = Theme.of(context);
    return ListView(
      controller: controller,
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Leaderboard', style: theme.textTheme.titleMedium),
              if (summary != null)
                Text(summary, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
        ...children,
      ],
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
      dense: true,
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
