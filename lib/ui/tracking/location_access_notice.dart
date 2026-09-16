import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/location_access.dart';
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

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notice.message),
            if (notice.label.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: action,
                  child: Text(notice.label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
