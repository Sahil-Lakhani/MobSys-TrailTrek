import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../data/local/database.dart';
import '../../data/local/elevation_codec.dart';
import '../../data/local/path_codec.dart';
import '../common/detail_scaffold.dart';
import '../common/elevation_chart.dart';
import '../common/stat_tile.dart';
import '../summary/run_summary_screen.dart' show formatArea, formatDuration;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tracking/tracking_map.dart' show osmLand, toMap;

/// One past run: the path it took, and what it was worth.
///
/// The path is decoded from the run's own `encodedPath` rather than recomputed, so this is
/// literally the track that was recorded — including for runs that never closed a loop, where
/// the path is the entire record.
class RunDetailScreen extends StatelessWidget {
  const RunDetailScreen({required this.run, super.key});

  final Run run;

  static String _date(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.${d.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = PathCodec.decode(run.encodedPath);
    final points = path.map(toMap).toList();
    final claimed = run.areaM2 > 0;
    final elevationSeries = ElevationCodec.decode(run.encodedElevation);

    return DetailScaffold(
      title: run.title,
      eyebrow: _date(run.startedAt),
      map: points.length < 2
          // A run with no usable path still has its numbers; showing a broken map would be
          // worse than showing none.
          ? ColoredBox(
              color: AppColors.surface,
              child: Center(
                child: Text(
                  'No path recorded for this run.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          : FlutterMap(
              options: MapOptions(
                // Tiles arrive a moment after the map does, and flutter_map paints the gap in
                // its default grey — a hard block that reads as a rendering fault. This is
                // OpenStreetMap's own land tone, so a tile still loading is a shade of the map
                // rather than a hole in it.
                backgroundColor: osmLand,
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(points),
                  padding: const EdgeInsets.fromLTRB(36, 80, 36, 36),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'de.hsm.claimtrek',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      color: AppColors.accent,
                      strokeWidth: 5,
                      borderColor: AppColors.bg,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: points.first,
                      width: 20,
                      height: 20,
                      child: const TrackPin(color: AppColors.success),
                    ),
                    Marker(
                      point: points.last,
                      width: 20,
                      height: 20,
                      child: const TrackPin(color: AppColors.danger),
                    ),
                  ],
                ),
              ],
            ),
      children: [
        Text(
          claimed
              ? '${formatArea(run.areaM2)} claimed'
              : 'No loop closed — nothing claimed',
          style: claimed
              ? AppTheme.number(30, color: AppColors.accent)
              : theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
        ),

        // Only meaningful where ground was actually taken.
        if (claimed && !run.verified)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Pill.warning(
                label: 'Unverified — excluded from the leaderboard',
              ),
            ),
          ),
        const SizedBox(height: 18),
        DetailSection(
          child: StatGrid(
            children: [
              StatTile(label: 'Distance', value: '${run.distanceM.round()} m'),
              StatTile(
                label: 'Time',
                value: formatDuration(Duration(milliseconds: run.durationMs)),
              ),
              if (run.steps > 0)
                StatTile(label: 'Steps', value: '${run.steps}'),
              if (run.elevationGainM > 0)
                StatTile(
                  label: 'Climb',
                  value: '${run.elevationGainM.round()} m',
                ),
            ],
          ),
        ),
        if (elevationSeries.length >= 2) ...[
          const SizedBox(height: 12),
          DetailSection(
            title: 'Elevation',
            child: ElevationChart(samples: elevationSeries),
          ),
        ],
      ],
    );
  }
}
