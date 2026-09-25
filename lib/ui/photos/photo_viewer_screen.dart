import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../tracking/run_stats_hud.dart' show formatDistance;

/// `14:05` — the time of day a photo was taken.
String formatClock(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// A square crop of a run photo, decoded at thumbnail size so a grid of them stays cheap.
class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({required this.filePath, this.size = 88, super.key});

  final String filePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(filePath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: pixels,
        // A photo whose file has gone (cleared storage, a restored backup) shows as missing
        // rather than taking the whole screen down with it.
        errorBuilder: (context, _, _) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

/// Full-screen photos, swiped through and pinched to zoom.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    required this.photos,
    this.initialIndex = 0,
    this.captionFor,
    super.key,
  });

  final List<RunPhoto> photos;
  final int initialIndex;

  /// An extra line under each photo — the gallery uses it to name the run it came from.
  final String Function(RunPhoto photo)? captionFor;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    final caption = widget.captionFor?.call(photo);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} of ${widget.photos.length}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image.file(
                    File(widget.photos[i].filePath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (caption != null)
                      Text(
                        caption,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    Text(
                      '${formatClock(photo.takenAt)} · '
                      '${formatDistance(photo.distanceM)} into the run',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
