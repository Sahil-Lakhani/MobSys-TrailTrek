import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/elevation_codec.dart';
import '../../data/local/path_codec.dart';
import '../../data/photos/run_photos.dart';
import '../../data/providers.dart';
import '../common/detail_scaffold.dart';
import '../common/elevation_chart.dart';
import '../common/run_photo.dart';
import '../common/stat_tile.dart';
import '../summary/run_summary_screen.dart' show formatArea, formatDuration;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tracking/tracking_map.dart' show osmLand, toMap;

class RunDetailScreen extends ConsumerStatefulWidget {
  const RunDetailScreen({required this.run, super.key});

  final Run run;

  @override
  ConsumerState<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends ConsumerState<RunDetailScreen> {
  late Run _run = widget.run;
  bool _busy = false;

  Future<void> _change(Future<Run?> Function(RunPhotos photos) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final photos = await ref.read(runPhotosProvider.future);
      final updated = await action(photos);
      if (updated != null && mounted) setState(() => _run = updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the photo')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takePhoto() async {
    final source = await takeRunPhoto(context);
    if (source == null) return;
    await _change((photos) => photos.attach(_run, source));
  }

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
    final run = _run;
    final theme = Theme.of(context);
    final path = PathCodec.decode(run.encodedPath);
    final points = path.map(toMap).toList();
    final claimed = run.areaM2 > 0;
    final elevationSeries = ElevationCodec.decode(run.encodedElevation);

    return DetailScaffold(
      title: run.title,
      eyebrow: _date(run.startedAt),
      map: points.length < 2
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
        const SizedBox(height: 12),
        MemoryCard(
          photo: run.photoPath == null
              ? null
              : RunPhotoImage(path: run.photoPath!),
          onTake: _busy ? () {} : _takePhoto,
          onRemove: _busy
              ? null
              : () => _change((photos) => photos.remove(_run)),
          onOpen: run.photoPath == null
              ? null
              : () => PhotoViewerScreen.open(
                  context,
                  RunPhotoImage(path: run.photoPath!, fit: BoxFit.contain),
                ),
        ),
      ],
    );
  }
}
