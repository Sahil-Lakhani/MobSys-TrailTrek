import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/location_access.dart';
import '../common/glass_panel.dart';
import '../theme/app_colors.dart';
import 'tracking_controller.dart';

/// What to say, and what to offer, for each way location can be unavailable.
///
/// Kept as one exhaustive switch so a new [LocationAccess] value cannot be added without
/// deciding what the user sees. Collapsing these into "location unavailable" would offer a
/// retry button to someone who chose "don't ask again", where retrying does nothing at all.
({String message, String label}) noticeFor(LocationAccess access) =>
    switch (access) {
      LocationAccess.granted => (message: '', label: ''),
      LocationAccess.requesting => (message: 'Asking for location…', label: ''),
      LocationAccess.notRequested => (
        message: 'Showing the demo area until location is allowed.',
        label: 'Allow location',
      ),
      LocationAccess.denied => (
        message: 'ClaimTrek needs location to record where you run.',
        label: 'Allow location',
      ),
      LocationAccess.deniedForever => (
        message: 'Location is blocked. Only app settings can turn it back on.',
        label: 'Open app settings',
      ),
      LocationAccess.servicesDisabled => (
        message: 'Location is switched off on this phone.',
        label: 'Open location settings',
      ),
    };

class LocationAccessNotice extends ConsumerWidget {
  const LocationAccessNotice({required this.access, super.key});

  final LocationAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = noticeFor(access);
    if (notice.message.isEmpty) return const SizedBox.shrink();

    final controller = ref.read(trackingControllerProvider.notifier);

    // A refusal can be asked again; a permanent block or a system switch cannot, and sending
    // the user to the wrong settings screen is its own dead end.
    final action = switch (access) {
      LocationAccess.deniedForever ||
      LocationAccess.servicesDisabled => controller.openSettings,
      _ => controller.retryLocation,
    };

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_rounded,
              size: 18,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notice.message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.text, height: 1.3),
            ),
          ),
          if (notice.label.isNotEmpty) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: action,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(notice.label),
            ),
          ],
        ],
      ),
    );
  }
}
