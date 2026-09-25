import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/providers.dart';
import '../auth/account_action.dart';
import '../common/empty_state.dart';
import '../summary/run_summary_screen.dart' show formatArea, formatDuration;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: runs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Runs unavailable: $error'),
            ),
          ),
          data: (list) => ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
            children: [
              const _Header(),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: EmptyState(
                    icon: Icons.directions_run_rounded,
                    title: 'No runs yet',
                    body: 'Runs you save land here — whether or not they closed a loop.',
                  ),
                )
              else ...[
                _Totals(runs: list),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'HISTORY',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                for (final run in list) ...[
                  _RunCard(run: run),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Your runs',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const AccountAction(glass: false),
      ],
    );
  }
}

/// Lifetime numbers across the whole history.
///
/// Number and unit are separate widgets so the figure can be big and the unit quiet.
class _Totals extends StatelessWidget {
  const _Totals({required this.runs});

  final List<Run> runs;

  @override
  Widget build(BuildContext context) {
    final distanceM = runs.fold<double>(0, (sum, r) => sum + r.distanceM);
    final areaM2 = runs.fold<double>(0, (sum, r) => sum + r.areaM2);
    final loops = runs.where((r) => r.areaM2 > 0).length;

    final (areaValue, areaUnit) = areaM2 >= 10000
        ? ((areaM2 / 10000).toStringAsFixed(2), 'ha')
        : (areaM2.round().toString(), 'm²');

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GROUND HELD',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: 6),
          _BigFigure(value: areaValue, unit: areaUnit, size: 44),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Labelled(
                  label: 'Runs',
                  child: _BigFigure(value: '${runs.length}', size: 22),
                ),
              ),
              Expanded(
                child: _Labelled(
                  label: 'Distance',
                  child: _BigFigure(
                    value: (distanceM / 1000).toStringAsFixed(1),
                    unit: 'km',
                    size: 22,
                  ),
                ),
              ),
              Expanded(
                child: _Labelled(
                  label: 'Loops',
                  child: _BigFigure(value: '$loops', size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontSize: 10.5),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _BigFigure extends StatelessWidget {
  const _BigFigure({required this.value, this.unit, required this.size});

  final String value;
  final String? unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: AppTheme.number(size)),
        if (unit != null) ...[
          const SizedBox(width: 4),
          Text(
            unit!,
            style: AppTheme.number(size * 0.45, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final Run run;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _date(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final claimed = run.areaM2 > 0;

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => RunDetailScreen(run: run)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lime for a run that took ground, grey for one that did not: the list can be
              // read at a glance for which runs paid off.
              Container(
                width: 4,
                color: claimed ? AppColors.accent : AppColors.outline,
              ),
              Expanded(
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 6, 16, 6),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: claimed
                          ? AppColors.accent.withValues(alpha: 0.12)
                          : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      claimed
                          ? Icons.hexagon_rounded
                          : Icons.directions_run_rounded,
                      size: 22,
                      color: claimed ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                  title: Text(
                    run.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${_date(run.startedAt)} · ${run.distanceM.round()} m · '
                      '${formatDuration(Duration(milliseconds: run.durationMs))}',
                    ),
                  ),
                  trailing: Text(
                    // "no loop" rather than "0 m²": nothing was claimed because the shape
                    // never closed, which is a different thing from claiming an area of
                    // nothing.
                    claimed ? formatArea(run.areaM2) : 'no loop',
                    style: claimed
                        ? AppTheme.number(17, color: AppColors.accent)
                        : theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
