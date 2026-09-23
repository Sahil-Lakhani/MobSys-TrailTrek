import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

/// The account control for an app bar: sign in, or show who is signed in.
///
/// Renders nothing at all when Firebase did not start. ClaimTrek plays perfectly well with no
/// account — offering a sign-in button that cannot work would be worse than staying quiet,
/// which is the same rule the run counter follows for a sensor the device lacks.
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
        if (user == null) {
          return IconButton(
            tooltip: 'Sign in',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/signin'),
          );
        }

        final label = (user.displayName ?? user.email ?? '?').trim();
        final initial = label.isEmpty ? '?' : label[0].toUpperCase();

        return PopupMenuButton<String>(
          tooltip: label,
          icon: CircleAvatar(
            radius: 14,
            foregroundImage: user.photoURL == null
                ? null
                : NetworkImage(user.photoURL!),
            child: Text(initial, style: const TextStyle(fontSize: 13)),
          ),
          onSelected: (value) async {
            if (value == 'signout') {
              await ref.read(authServiceProvider).signOut();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            const PopupMenuItem<String>(
              value: 'signout',
              child: Text('Sign out'),
            ),
          ],
        );
      },
    );
  }
}
