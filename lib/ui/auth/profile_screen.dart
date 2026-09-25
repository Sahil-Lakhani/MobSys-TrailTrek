import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/player_identity.dart';
import '../../data/providers.dart';
import '../theme/app_colors.dart';
import '../tracking/tracking_map.dart' show parseHex;
import 'account_action.dart' show PlayerAvatar;

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
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
      height: 1.35,
    );

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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _ProfileHeader(player: player),
              const SizedBox(height: 12),

              _Section(
                icon: Icons.badge_outlined,
                title: 'Display name',
                children: [
                  Text(
                    player.usesAccountName
                        ? 'Currently using your Google name. Type something here to override it.'
                        : 'Shown on the leaderboard and on ground you claim.',
                    style: muted,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _name,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: player.usesAccountName ? player.name : null,
                      // Clearing it is a real choice, not an accident: it hands the display
                      // back to the Google name.
                      helperText: 'Leave empty to use your account name',
                    ),
                    onSubmitted: (value) => _apply(() => player.setName(value)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
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
                ],
              ),
              const SizedBox(height: 12),

              _Section(
                icon: Icons.palette_outlined,
                title: 'Your colour',
                children: [
                  Text(
                    'The ground you hold is drawn in this colour.',
                    style: muted,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final hex in playerColours)
                        _ColourDot(
                          hex: hex,
                          selected:
                              hex.toUpperCase() ==
                              player.colorHex.toUpperCase(),
                          onTap: _busy
                              ? null
                              : () => _apply(() => player.setColorHex(hex)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _AccountCard(player: player, firebaseReady: firebaseReady),
            ],
          );
        },
      ),
    );
  }
}

/// Big avatar and name: who the board thinks you are.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.player});

  final PlayerIdentity player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF26300F), AppColors.surface],
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          PlayerAvatar(
            name: player.name,
            colorHex: player.colorHex,
            photoUrl: player.photoUrl,
            radius: 30,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  player.isSignedIn ? 'Signed in' : 'Playing on this device',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A card with an icon and title, grouping one setting.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.accent),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
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
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.textMuted,
      height: 1.35,
    );

    // Nothing about accounts is offered on a build where Firebase never started; the game is
    // fully playable without one, and a control that cannot work is worse than none.
    if (!firebaseReady) {
      return _Section(
        icon: Icons.cloud_off_outlined,
        title: 'Playing offline',
        children: [
          Text(
            'Your runs and territory are stored on this device.',
            style: muted,
          ),
        ],
      );
    }

    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return _Section(
        icon: Icons.person_outline_rounded,
        title: 'Not signed in',
        children: [
          Text(
            'Sign in to carry your ground between devices and appear on the '
            'leaderboard alongside other players.',
            style: muted,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/signin'),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign in'),
            ),
          ),
        ],
      );
    }

    final label = (user.displayName ?? user.email ?? 'Signed in').trim();

    return _Section(
      icon: Icons.verified_user_outlined,
      title: 'Account',
      children: [
        Text(label, style: theme.textTheme.bodyLarge),
        if (user.email != null) Text(user.email!, style: muted),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
            ),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Signed out')));
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ),
      ],
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
    final colour = parseHex(hex, AppColors.accent);

    return Semantics(
      selected: selected,
      button: true,
      label: 'Colour $hex',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // A lime ring for the chosen one, reading as "selected" in the app's own voice
            // rather than in the swatch's colour.
            border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                : null,
          ),
        ),
      ),
    );
  }
}
