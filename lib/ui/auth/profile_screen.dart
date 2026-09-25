import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/player_identity.dart';
import '../../data/providers.dart';
import '../tracking/tracking_map.dart' show parseHex;

/// The colours a player can fly.
///
/// A fixed set rather than a full picker: these are drawn over a map, so they have to stay
/// legible against it and distinct from the seeded rivals.
const List<String> playerColours = [
  '#FF6B35',
  '#E8412C',
  '#F2B705',
  '#2E86DE',
  '#27AE60',
  '#8E44AD',
];

/// Who you are, and the two things about that you can change.
///
/// Reached from the account control rather than a fourth tab: the map is the centre of this
/// app, and pushing it further along the bar to make room for settings would be the wrong
/// trade.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _name = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Fills the field once. Rebinding it on every build would fight the keyboard.
  void _fillOnce(PlayerIdentity player) {
    if (_loaded) return;
    _loaded = true;
    _name.text = player.usesAccountName ? '' : player.name;
  }

  Future<void> _apply(Future<void> Function() change) async {
    setState(() => _busy = true);
    await change();
    // The name and colour are stamped onto every claim and every leaderboard row, so the
    // repository built from this identity has to be rebuilt before either is drawn again.
    ref.invalidate(playerIdentityProvider);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = ref.watch(playerIdentityProvider);
    final firebaseReady = ref.watch(firebaseReadyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: identity.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load your profile: $error'),
          ),
        ),
        data: (player) {
          _fillOnce(player);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _AccountCard(player: player, firebaseReady: firebaseReady),
              const SizedBox(height: 26),

              Text('Display name', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                player.usesAccountName
                    ? 'Currently using your Google name. Type something here to override it.'
                    : 'Shown on the leaderboard and on ground you claim.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                enabled: !_busy,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: player.usesAccountName ? player.name : null,
                  // Clearing it is a real choice, not an accident: it hands the display back
                  // to the Google name.
                  helperText: 'Leave empty to use your account name',
                ),
                onSubmitted: (value) => _apply(() => player.setName(value)),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await _apply(() => player.setName(_name.text));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Name saved')),
                          );
                        },
                  child: const Text('Save name'),
                ),
              ),

              const SizedBox(height: 26),
              Text('Your colour', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'The ground you hold is drawn in this colour.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final hex in playerColours)
                    _ColourDot(
                      hex: hex,
                      selected: hex.toUpperCase() == player.colorHex.toUpperCase(),
                      onTap: _busy
                          ? null
                          : () => _apply(() => player.setColorHex(hex)),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Who you are signed in as, or an invitation to be someone.
class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.player, required this.firebaseReady});

  final PlayerIdentity player;
  final bool firebaseReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Nothing about accounts is offered on a build where Firebase never started; the game is
    // fully playable without one, and an control that cannot work is worse than none.
    if (!firebaseReady) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('Playing offline'),
          subtitle: const Text(
            'Your runs and territory are stored on this device.',
          ),
        ),
      );
    }

    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Not signed in', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Sign in to carry your ground between devices and appear on the '
                'leaderboard alongside other players.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => context.push('/signin'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final label = (user.displayName ?? user.email ?? 'Signed in').trim();

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 22,
              foregroundImage: user.photoURL == null
                  ? null
                  : NetworkImage(user.photoURL!),
              child: Text(label.isEmpty ? '?' : label[0].toUpperCase()),
            ),
            title: Text(label),
            subtitle: user.email == null ? null : Text(user.email!),
          ),
          const Divider(height: 1),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: TextButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out')),
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColourDot extends StatelessWidget {
  const _ColourDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = parseHex(hex, theme.colorScheme.primary);

    return Semantics(
      selected: selected,
      button: true,
      label: 'Colour $hex',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? theme.colorScheme.onSurface : Colors.black26,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }
}
