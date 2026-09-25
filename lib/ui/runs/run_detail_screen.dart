import '../../data/local/elevation_codec.dart';
import '../common/elevation_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../data/local/database.dart';
import '../../data/local/path_codec.dart';
import '../../data/providers.dart';
import '../photos/photo_viewer_screen.dart';
import '../summary/run_summary_screen.dart' show formatArea, formatDuration;
import '../tracking/tracking_map.dart' show osmLand, toMap;

/// One past run: the path it took, and what it was worth.
///
/// The path is decoded from the run's own `encodedPath` rather than recomputed, so this is
/// literally the track that was recorded — including for runs that never closed a loop, where
/// the path is the entire record.
class RunDetailScreen extends ConsumerWidget {
  const RunDetailScreen({required this.run, super.key});

  final Run run;

  void _openPhoto(BuildContext context, List<RunPhoto> photos, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewerScreen(
          photos: photos,
          initialIndex: index,
          captionFor: (_) => run.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final photos = ref.watch(runPhotosProvider(run.id)).value ?? const [];
    final path = PathCodec.decode(run.encodedPath);
    final points = path.map(toMap).toList();
    final claimed = run.areaM2 > 0;
    final elevationSeries = ElevationCodec.decode(run.encodedElevation);

    return Scaffold(
      appBar: AppBar(title: Text(run.title)),
      body: Column(
        children: [
          Expanded(
            child: points.length < 2
                // A run with no usable path still has its numbers; showing a broken map would
                // be worse than showing none.
                ? Center(
                    child: Text(
                      'No path recorded for this run.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : FlutterMap(
                    options: MapOptions(
                      // Tiles arrive a moment after the map does, and flutter_map paints the gap
                      // in its default grey — a hard block that reads as a rendering fault. This
                      // is OpenStreetMap's own land tone, so a tile still loading is a shade of
                      // the map rather than a hole in it.
                      backgroundColor: osmLand,
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(points),
                        padding: const EdgeInsets.all(36),
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'de.hsm.claimtrek',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            color: Colors.amber.shade700,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: points.first,
                            width: 18,
                            height: 18,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(
                                  BorderSide(color: Colors.white, width: 3),
                                ),
                              ),
                            ),
                          ),
                          Marker(
                            point: points.last,
                            width: 18,
                            height: 18,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(
                                  BorderSide(color: Colors.white, width: 3),
                                ),
                              ),
                            ),
                          ),

                          // Where each photo was taken. Tapping one opens it.
                          for (var i = 0; i < photos.length; i++)
                            if (photos[i].lat != null && photos[i].lng != null)
                              Marker(
                                point: ll.LatLng(photos[i].lat!, photos[i].lng!),
                                width: 30,
                                height: 30,
                                child: GestureDetector(
                                  onTap: () => _openPhoto(context, photos, i),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: const Border.fromBorderSide(
                                        BorderSide(color: Colors.white, width: 2),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.photo_camera,
                                      size: 16,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    claimed
                        ? '${formatArea(run.areaM2)} claimed'
                        : 'No loop closed — nothing claimed',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 28,
                    runSpacing: 10,
                    children: [
                      _Stat(
                        label: 'Distance',
                        value: '${run.distanceM.round()} m',
                      ),
                      _Stat(
                        label: 'Time',
                        value: formatDuration(
                          Duration(milliseconds: run.durationMs),
                        ),
                      ),
                      if (run.steps > 0)
                        _Stat(label: 'Steps', value: '${run.steps}'),
                      if (run.elevationGainM > 0)
                        _Stat(
                          label: 'Climb',
                          value: '${run.elevationGainM.round()} m',
                        ),
                    ],
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Photos (${photos.length})',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 88,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) => GestureDetector(
                          onTap: () => _openPhoto(context, photos, i),
                          child: PhotoThumbnail(filePath: photos[i].filePath),
                        ),
                      ),
                    ),
                  ],
                  if (elevationSeries.length >= 2) ...[
                    const SizedBox(height: 18),
                    Text('Elevation', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ElevationChart(samples: elevationSeries),
                  ],

                  // Only meaningful where ground was actually taken.
                  if (claimed && !run.verified)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Unverified — excluded from the leaderboard',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
