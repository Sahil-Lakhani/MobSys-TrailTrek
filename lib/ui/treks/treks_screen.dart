import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/trail_repository.dart';
import '../../geo/lat_lng.dart';
import '../tracking/tracking_controller.dart';
import 'trek_detail_screen.dart';

/// Trails around wherever the runner currently is.
///
/// Keyed on the origin so that moving to a new area re-queries, while rebuilds at the same
/// place are served from the Drift cache without touching Overpass — which rate-limits.
final nearbyTrailsProvider =
    FutureProvider.family<List<TrailListing>, LatLng>((ref, centre) {
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
      appBar: AppBar(title: const Text('Treks near you')),
      body: origin == null
          ? const _Centred(
              icon: Icons.my_location,
              title: 'Finding you',
              detail: 'Trails are listed by how far away they start.',
            )
          : _TrailList(centre: origin),
    );
  }
}

class _TrailList extends ConsumerWidget {
  const _TrailList({required this.centre});

  final LatLng centre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trails = ref.watch(nearbyTrailsProvider(centre));

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(trailRepositoryProvider).expireAll();
        ref.invalidate(nearbyTrailsProvider(centre));
        await ref.read(nearbyTrailsProvider(centre).future);
      },
      child: trails.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(nearbyTrailsProvider(centre)),
        ),
        data: (list) => list.isEmpty
            ? const _Centred(
                icon: Icons.terrain_outlined,
                title: 'No mapped trails within 5 km',
                detail:
                    'ClaimTrek lists named walking routes from OpenStreetMap. '
                    'Pull down to look again.',
                scrollable: true,
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _TrailRow(trail: list[i]),
              ),
      ),
    );
  }
}

class _TrailRow extends StatelessWidget {
  const _TrailRow({required this.trail});

  final TrailListing trail;

  static String _km(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Icons.route_outlined),
      title: Text(trail.name),
      subtitle: Text(
        '${_km(trail.distanceM)} away · ${trail.kind}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(_km(trail.lengthM), style: theme.textTheme.titleMedium),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrekDetailScreen(trail: trail),
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
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(
          _rateLimited ? Icons.hourglass_top : Icons.cloud_off,
          size: 48,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _rateLimited ? 'OpenStreetMap is busy' : 'Could not reach OpenStreetMap',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _rateLimited
                ? 'The free Overpass service is rate-limited. Try again shortly.'
                : 'Check your connection and try again.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _Centred extends StatelessWidget {
  const _Centred({
    required this.icon,
    required this.title,
    required this.detail,
    this.scrollable = false,
  });

  final IconData icon;
  final String title;
  final String detail;

  /// A pull-to-refresh needs something scrollable underneath it, even when empty.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 48, color: theme.colorScheme.outline),
        const SizedBox(height: 12),
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(detail, textAlign: TextAlign.center),
        ),
      ],
    );

    return scrollable ? ListView(children: [content]) : Center(child: content);
  }
}
