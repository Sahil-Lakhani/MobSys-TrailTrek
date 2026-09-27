import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers.dart';
import '../theme/app_colors.dart';

Future<String?> takeRunPhoto(BuildContext context) async {
  try {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    return shot?.path;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The camera is not available')),
      );
    }
    return null;
  }
}

class RunPhotoImage extends ConsumerStatefulWidget {
  const RunPhotoImage({
    required this.path,
    this.fit = BoxFit.cover,
    this.placeholder,
    super.key,
  });

  final String path;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  ConsumerState<RunPhotoImage> createState() => _RunPhotoImageState();
}

class _RunPhotoImageState extends ConsumerState<RunPhotoImage> {
  late Future<File?> _file = _resolve();

  Future<File?> _resolve() =>
      ref.read(runPhotoStoreProvider).resolve(widget.path);

  @override
  void didUpdateWidget(RunPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _file = _resolve();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return widget.placeholder ??
              const ColoredBox(color: AppColors.surfaceHigh);
        }
        return Image.file(
          file,
          fit: widget.fit,
          errorBuilder: (_, _, _) =>
              widget.placeholder ??
              const ColoredBox(color: AppColors.surfaceHigh),
        );
      },
    );
  }
}

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({required this.child, super.key});

  final Widget child;

  static Future<void> open(BuildContext context, Widget child) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhotoViewerScreen(child: child),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(child: InteractiveViewer(maxScale: 5, child: child)),
    );
  }
}

class MemoryCard extends StatelessWidget {
  const MemoryCard({
    required this.photo,
    required this.onTake,
    this.onRemove,
    this.onOpen,
    super.key,
  });

  final Widget? photo;
  final VoidCallback onTake;
  final VoidCallback? onRemove;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.photo_camera_rounded,
                  size: 20,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                Text('Memory', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (photo == null) ...[
              Text(
                'Snap a picture to remember this run. It stays on this phone.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onTake,
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text('Take a photo'),
              ),
            ] else ...[
              GestureDetector(
                onTap: onOpen,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(aspectRatio: 4 / 3, child: photo),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTake,
                      icon: const Icon(Icons.cameraswitch_rounded),
                      label: const Text('Retake'),
                    ),
                  ),
                  if (onRemove != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRemove,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(
                            color: AppColors.danger.withValues(alpha: 0.5),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Remove'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
