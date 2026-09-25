import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

/// The account control for an app bar: the way through to your profile.
///
/// Renders nothing at all when Firebase did not start. ClaimTrek plays perfectly well with no
/// account — offering a control that cannot work would be worse than staying quiet, which is
/// the same rule the run counter follows for a sensor the device lacks.
class AccountAction extends ConsumerWidget {
  const AccountAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(firebaseReadyProvider)) return const SizedBox.shrink();

    final auth = ref.watch(authStateProvider);

    return auth.when(
      // Never a spinner in an app bar: the slot would twitch on every rebuild.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (user) {
        // One destination either way. Sign-out used to live in a popup here, which is not
        // where anyone looks for it; the profile screen is.
        void open() => context.push('/profile');

        if (user == null) {
          return IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: open,
          );
        }

        final label = (user.displayName ?? user.email ?? '?').trim();
        final initial = label.isEmpty ? '?' : label[0].toUpperCase();

        return IconButton(
          tooltip: label,
          onPressed: open,
          icon: CircleAvatar(
            radius: 14,
            foregroundImage: user.photoURL == null
                ? null
                : NetworkImage(user.photoURL!),
            child: Text(initial, style: const TextStyle(fontSize: 13)),
          ),
        );
      },
    );
  }
}
