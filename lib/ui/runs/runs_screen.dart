import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/providers.dart';
import '../summary/run_summary_screen.dart' show formatArea, formatDuration;
import 'run_detail_screen.dart';

/// Everything you have run.
///
/// Runs that never closed a loop are listed alongside the ones that did. They took no ground,
/// so they carry no area — but a run you actually went out and did should not vanish because
/// the shape did not work out.
class RunsScreen extends ConsumerWidget {
  const RunsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(runsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Runs')),
      body: runs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Runs unavailable: $error'),
          ),
        ),
        data: (list) => list.isEmpty
            ? const _Empty()
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _RunRow(run: list[i]),
              ),
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run});

  final Run run;

  static String _date(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final claimed = run.areaM2 > 0;

    return ListTile(
      leading: Icon(
        claimed ? Icons.hexagon_outlined : Icons.timeline,
        color: claimed ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      title: Text(run.title),
      subtitle: Text(
        '${_date(run.startedAt)} · ${run.distanceM.round()} m · '
        '${formatDuration(Duration(milliseconds: run.durationMs))}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(
        // "no loop" rather than "0 m²": nothing was claimed because the shape never closed,
        // which is a different thing from claiming an area of nothing.
        claimed ? formatArea(run.areaM2) : 'no loop',
        style: claimed
            ? theme.textTheme.titleMedium
            : theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RunDetailScreen(run: run)),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('No runs yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Runs you save land here — whether or not they closed a loop.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
