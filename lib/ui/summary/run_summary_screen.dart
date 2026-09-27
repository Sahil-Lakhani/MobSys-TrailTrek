import 'dart:io';

import '../common/elevation_chart.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/run_photo.dart';
import '../common/stat_tile.dart';
import '../theme/app_colors.dart';
import '../tracking/tracking_controller.dart';
import '../tracking/tracking_map.dart' show osmLand, territoryPolygons, toMap;

String formatArea(double m2) =>
    m2 >= 10000 ? '${(m2 / 10000).toStringAsFixed(2)} ha' : '${m2.round()} m²';

String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return minutes >= 60
      ? '${d.inHours}:${minutes.remainder(60).toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}

class RunSummaryScreen extends ConsumerStatefulWidget {
  const RunSummaryScreen({required this.run, super.key});

  final PendingRun run;

  @override
  ConsumerState<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends ConsumerState<RunSummaryScreen> {
  late final TextEditingController _title = TextEditingController(
    text: defaultRunTitle(),
  );
  bool _saving = false;
  String? _photo;

  Future<void> _takePhoto() async {
    final path = await takeRunPhoto(context);
    if (path != null && mounted) setState(() => _photo = path);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    await ref
        .read(trackingControllerProvider.notifier)
        .saveRun(title: _title.text, photoSourcePath: _photo);

    if (mounted) Navigator.of(context).pop();
  }

  void _discard() {
    ref.read(trackingControllerProvider.notifier).discardRun();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final availability = ref.watch(
      trackingControllerProvider.select((s) => s.availability),
    );
    final theme = Theme.of(context);
    final claimed = run.claimedGround;

    return PopScope(
      canPop: false,
      child: Scaffold(
        bottomNavigationBar: _DecisionBar(
          saving: _saving,
          onSave: _save,
          onDiscard: _discard,
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Banner(claimed: claimed),
                const SizedBox(height: 18),
                _ClaimMap(run: run),
                const SizedBox(height: 14),

                if (!claimed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'No loop closed — nothing claimed.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StatTile(
                              label: 'Claimed',
                              value: formatArea(run.areaM2),
                              size: 32,
                              valueColor: AppColors.accent,
                            ),
                          ),
                          Expanded(
                            child: StatTile(
                              label: 'Stolen',
                              value: run.stolenAreaM2 <= 0
                                  ? '—'
                                  : formatArea(run.stolenAreaM2),
                              size: 32,
                              detail: run.stolenFromCount == 0
                                  ? null
                                  : 'from ${run.stolenFromCount} '
                                        '${run.stolenFromCount == 1 ? "player" : "players"}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: StatGrid(
                      children: [
                        StatTile(
                          label: 'Distance',
                          value: '${run.distanceM.round()} m',
                        ),
                        StatTile(
                          label: 'Time',
                          value: formatDuration(run.duration),
                        ),
                        if (availability.pedometer)
                          StatTile(label: 'Steps', value: '${run.steps}'),
                        if (availability.barometer)
                          StatTile(
                            label: 'Climb',
                            value: '${run.elevationGainM.round()} m',
                          ),
                      ],
                    ),
                  ),
                ),

                if (claimed && !run.verified) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Unverified — this run did not look like running, so the ground '
                            'is yours to keep but will not count on the leaderboard.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.text,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Name this run',
                    prefixIcon: Icon(Icons.edit_rounded, size: 20),
                  ),
                ),

                const SizedBox(height: 12),
                MemoryCard(
                  photo: _photo == null
                      ? null
                      : Image.file(File(_photo!), fit: BoxFit.cover),
                  onTake: _takePhoto,
                  onRemove: () => setState(() => _photo = null),
                  onOpen: () => PhotoViewerScreen.open(
                    context,
                    Image.file(File(_photo!)),
                  ),
                ),

                if (run.elevationSeries.length >= 2) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Elevation', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 14),
                          ElevationChart(samples: run.elevationSeries),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.claimed});

  final bool claimed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: claimed ? AppColors.accent : AppColors.surfaceHigh,
            shape: BoxShape.circle,
            boxShadow: claimed
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            claimed ? Icons.flag_rounded : Icons.directions_run_rounded,
            color: claimed ? AppColors.onAccent : AppColors.text,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                claimed ? 'Ground taken!' : 'Run complete',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                claimed
                    ? 'Save it to put your flag on the map.'
                    : 'Keep it in your history, or let it go.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DecisionBar extends StatelessWidget {
  const _DecisionBar({
    required this.saving,
    required this.onSave,
    required this.onDiscard,
  });

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : onDiscard,
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: saving ? null : onSave,
                      child: Text(saving ? 'Saving…' : 'Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Discarding leaves the map exactly as it was.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaimMap extends StatelessWidget {
  const _ClaimMap({required this.run});

  final PendingRun run;

  @override
  Widget build(BuildContext context) {
    final points = run.track.map(toMap).toList();
    final claim = run.claim;

    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FlutterMap(
          options: MapOptions(
            backgroundColor: osmLand,
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(28),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.hsm.claimtrek',
            ),
            if (claim != null)
              PolygonLayer(
                polygons: territoryPolygons(
                  claim,
                  fill: AppColors.accent.withValues(alpha: 0.45),
                  border: AppColors.bg,
                  borderWidth: 2.5,
                ),
              ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: AppColors.accent,
                  strokeWidth: 4,
                  borderColor: AppColors.bg,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
