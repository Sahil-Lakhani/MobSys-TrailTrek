import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/providers.dart';
import '../runs/run_detail_screen.dart';
import 'photo_viewer_screen.dart';

/// `25/09/2026`.
String _date(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Every photo taken on a run, newest first, grouped under the run it came from.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(allPhotosProvider);
    final runs = ref.watch(runsProvider).value ?? const <Run>[];
    final runsById = {for (final run in runs) run.id: run};

    return Scaffold(
      appBar: AppBar(title: const Text('Run photos')),
      body: photos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Photos unavailable: $error')),
        data: (all) {
          if (all.isEmpty) return const _Empty();

          // Photos arrive newest first, so the groups do too.
          final groups = <String, List<RunPhoto>>{};
          for (final photo in all) {
            groups.putIfAbsent(photo.runId, () => []).add(photo);
          }

          String captionFor(RunPhoto photo) {
            final run = runsById[photo.runId];
            return run == null
                ? _date(photo.takenAt)
                : '${run.title} · ${_date(run.startedAt)}';
          }

          return ListView(
            // Clear of the floating tab bar, which the shell lays over the bottom.
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              for (final entry in groups.entries)
                _RunGroup(
                  run: runsById[entry.key],
                  // In the order they were taken, which is how a run is remembered.
                  photos: entry.value.reversed.toList(),
                  captionFor: captionFor,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RunGroup extends StatelessWidget {
  const _RunGroup({
    required this.run,
    required this.photos,
    required this.captionFor,
  });

  final Run? run;
  final List<RunPhoto> photos;
  final String Function(RunPhoto) captionFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final run = this.run;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(run?.title ?? 'Run', style: theme.textTheme.titleMedium),
          subtitle: Text(
            '${run == null ? _date(photos.first.takenAt) : _date(run.startedAt)}'
            ' · ${photos.length} ${photos.length == 1 ? "photo" : "photos"}',
          ),
          trailing: run == null ? null : const Icon(Icons.chevron_right),
          onTap: run == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RunDetailScreen(run: run),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < photos.length; i++)
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PhotoViewerScreen(
                        photos: photos,
                        initialIndex: i,
                        captionFor: captionFor,
                      ),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) => PhotoThumbnail(
                      filePath: photos[i].filePath,
                      size: box.maxWidth,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
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
          Icon(Icons.photo_library_outlined, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('No photos yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap the camera button while running. Photos from saved runs land here.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
