import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/trail_repository.dart';
import '../../geo/lat_lng.dart';
import '../common/empty_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tracking/tracking_controller.dart';
import 'trek_detail_screen.dart';

/// Trails around wherever the runner currently is.
///
/// Keyed on the origin so that moving to a new area re-queries, while rebuilds at the same
/// place are served from the Drift cache without touching Overpass — which rate-limits.
final nearbyTrailsProvider = FutureProvider.family<List<TrailListing>, LatLng>((
  ref,
  centre,
) {
  return ref.watch(trailRepositoryProvider).nearby(centre);
});

class TreksScreen extends ConsumerWidget {
  const TreksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(
      trackingControllerProvider.select((s) => s.origin),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: origin == null
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: const [
                  _Header(),
                  SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.my_location_rounded,
                    title: 'Finding you',
                    body: 'Trails are listed by how far away they start.',
                  ),
                ],
              )
            : _TrailList(centre: origin),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Treks near you', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Named walking routes from OpenStreetMap',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Length buckets for the filter chips.
enum _Length {
  all('All'),
  short('Under 5 km'),
  medium('5–15 km'),
  long('15 km+');

  const _Length(this.label);
  final String label;

  bool matches(TrailListing trail) => switch (this) {
    _Length.all => true,
    _Length.short => trail.lengthM < 5000,
    _Length.medium => trail.lengthM >= 5000 && trail.lengthM < 15000,
    _Length.long => trail.lengthM >= 15000,
  };
}

class _TrailList extends ConsumerStatefulWidget {
  const _TrailList({required this.centre});

  final LatLng centre;

  @override
  ConsumerState<_TrailList> createState() => _TrailListState();
}

class _TrailListState extends ConsumerState<_TrailList> {
  _Length _filter = _Length.all;

  List<Widget> _data(List<TrailListing> list) {
    if (list.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 60),
          child: EmptyState(
            icon: Icons.terrain_rounded,
            title: 'No mapped trails within 5 km',
            body:
                'ClaimTrek lists named walking routes from OpenStreetMap. '
                'Pull down to look again.',
          ),
        ),
      ];
    }

    final shown = list.where(_filter.matches).toList();
    return [
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final f in _Length.values) ...[
              ChoiceChip(
                label: Text(f.label),
                selected: f == _filter,
                showCheckmark: false,
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: f == _filter ? AppColors.onAccent : AppColors.text,
                ),
                onSelected: (_) => setState(() => _filter = f),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: EmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'Nothing that length nearby',
            body: '${list.length} trails around, just none in this range.',
          ),
        )
      else
        for (final trail in shown) ...[
          _TrailCard(trail: trail),
          const SizedBox(height: 10),
        ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final centre = widget.centre;
    final trails = ref.watch(nearbyTrailsProvider(centre));
    final bottom = MediaQuery.paddingOf(context).bottom;

    final body = trails.when<List<Widget>>(
      loading: () => const [
        Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, _) => [
        _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(nearbyTrailsProvider(centre)),
        ),
      ],
      data: _data,
    );

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(trailRepositoryProvider).expireAll();
        ref.invalidate(nearbyTrailsProvider(centre));
        await ref.read(nearbyTrailsProvider(centre).future);
      },
      child: ListView(
        // A pull-to-refresh needs something scrollable underneath it, even when empty.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
        children: [const _Header(), const SizedBox(height: 18), ...body],
      ),
    );
  }
}

class _TrailCard extends StatelessWidget {
  const _TrailCard({required this.trail});

  final TrailListing trail;

  static String _km(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (value, unit) = trail.lengthM >= 1000
        ? ((trail.lengthM / 1000).toStringAsFixed(1), 'km')
        : (trail.lengthM.round().toString(), 'm');

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrekDetailScreen(trail: trail),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trail.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me_rounded,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_km(trail.distanceM)} away · ${trail.kind}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: AppTheme.number(20)),
                  Text(
                    unit,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offline and rate-limited read differently from "there is nothing here", so they get their
/// own screen with a retry rather than an empty list.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  bool get _rateLimited =>
      error is DioException &&
      (error as DioException).response?.statusCode == 429;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: EmptyState(
        icon: _rateLimited
            ? Icons.hourglass_top_rounded
            : Icons.cloud_off_rounded,
        title: _rateLimited
            ? 'OpenStreetMap is busy'
            : 'Could not reach OpenStreetMap',
        body: _rateLimited
            ? 'The free Overpass service is rate-limited. Try again shortly.'
            : 'Check your connection and try again.',
        action: FilledButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ),
    );
  }
}
