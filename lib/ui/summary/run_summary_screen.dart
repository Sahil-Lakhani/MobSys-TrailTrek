import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tracking/tracking_controller.dart';
import '../tracking/tracking_map.dart' show toMap, territoryPolygons;

String formatArea(double m2) => m2 >= 10000
    ? '${(m2 / 10000).toStringAsFixed(2)} ha'
    : '${m2.round()} m²';

String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return minutes >= 60
      ? '${d.inHours}:${minutes.remainder(60).toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}

/// The commit point.
///
/// Takes its [run] as a snapshot rather than reading the controller, so the screen cannot be
/// pulled out from under itself when the state clears on save, and so a widget test can render
/// it without a database.
///
/// Nothing here has been written yet. Discard genuinely leaves the world untouched, which is
/// only true because the claim was previewed rather than committed when the loop closed.
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

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Committing is a round trip through storage; a second tap would claim twice.
    if (_saving) return;
    setState(() => _saving = true);

    await ref
        .read(trackingControllerProvider.notifier)
        .saveRun(title: _title.text);

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

    return PopScope(
      // Backing out would be a third answer to a two-answer question, and would leave a
      // pending claim stranded behind the map.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Run summary'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ClaimMap(run: run),
            const SizedBox(height: 20),

            // A run that closed no loop took no ground. Showing "0 ha claimed" would read as a
            // failure; it is just a run, and it is still worth keeping.
            if (!run.claimedGround)
              Text(
                'No loop closed — nothing claimed.',
                style: theme.textTheme.titleMedium,
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Headline(
                      label: 'Claimed',
                      value: formatArea(run.areaM2),
                    ),
                  ),
                  Expanded(
                    child: _Headline(
                      label: 'Stolen',
                      value: run.stolenAreaM2 <= 0
                          ? '—'
                          : formatArea(run.stolenAreaM2),
                      detail: run.stolenFromCount == 0
                          ? null
                          : 'from ${run.stolenFromCount} '
                                '${run.stolenFromCount == 1 ? "player" : "players"}',
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _Stat(label: 'Distance', value: '${run.distanceM.round()} m'),
                _Stat(label: 'Time', value: formatDuration(run.duration)),
                // Same rule as the map: a sensor the device lacks hides its stat entirely.
                if (availability.pedometer)
                  _Stat(label: 'Steps', value: '${run.steps}'),
                if (availability.barometer)
                  _Stat(
                    label: 'Climb',
                    value: '${run.elevationGainM.round()} m',
                  ),
              ],
            ),

            if (run.claimedGround && !run.verified) ...[
              const SizedBox(height: 20),
              Card(
                color: theme.colorScheme.errorContainer,
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Unverified — this run did not look like running, so the ground is '
                    'yours to keep but will not count on the leaderboard.',
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Name this run',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _discard,
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Discarding leaves the map exactly as it was.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The ground this run enclosed, with the track that drew it.
class _ClaimMap extends StatelessWidget {
  const _ClaimMap({required this.run});

  final PendingRun run;

  @override
  Widget build(BuildContext context) {
    final points = run.track.map(toMap).toList();
    final claim = run.claim;

    return SizedBox(
      height: 240,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(28),
            ),
            // A summary is for reading, not panning; the gestures belong to the list.
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.hsm.claimtrek',
            ),
            // Nothing to shade when no loop closed — the path alone is the record.
            if (claim != null)
              PolygonLayer(
                polygons: territoryPolygons(
                  claim,
                  fill: Colors.orange.withValues(alpha: 0.35),
                  border: Colors.deepOrange,
                ),
              ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: Colors.amber.shade700,
                  strokeWidth: 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.headlineSmall),
        if (detail != null)
          Text(detail!, style: theme.textTheme.bodySmall),
      ],
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
