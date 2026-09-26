import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/player_identity.dart';
import '../../data/providers.dart';
import '../../testing_tools.dart';
import '../common/area_format.dart';
import '../common/stat_tile.dart';
import '../theme/app_colors.dart';
import '../tracking/run_stats_hud.dart' show formatDistance;
import '../tracking/tracking_controller.dart';
import 'account_action.dart' show PlayerAvatar;
import 'edit_profile_screen.dart';
import 'profile_banner.dart';
import 'sign_in_screen.dart' show EmailMode, SignInScreen;

export 'edit_profile_screen.dart' show playerColours;

/// The Profile tab: your whole profile at a glance, and one Edit button to change any of it.
///
/// Read-only on purpose. Mixing inputs into the view is what left a Save button sitting under
/// a name that had already been saved; here everything editable lives behind Edit, and saves
/// together.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(playerIdentityProvider);
    final firebaseReady = ref.watch(firebaseReadyProvider);
    // Reading auth at all requires Firebase to have started.
    final user = firebaseReady ? ref.watch(authStateProvider).value : null;
    final padding = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The banner runs under the status bar.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: identity.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load your profile: $error'),
            ),
          ),
          data: (player) => ListView(
            // Clear of the floating tab bar, which the shell lays over the bottom.
            padding: EdgeInsets.only(bottom: padding.bottom + 24),
            children: [
              ProfileBanner(
                colorHex: player.colorHex,
                topInset: padding.top,
                action: _EditButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => EditProfileScreen(player: player),
                    ),
                  ),
                ),
                avatar: ProfileAvatarRing(
                  child: PlayerAvatar(
                    name: player.name,
                    colorHex: player.colorHex,
                    photoUrl: player.photoUrl,
                    photoPath: player.photoPath,
                    radius: 46,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Identity(player: player, user: user),
                    const SizedBox(height: 16),
                    if (player.bio != null) ...[
                      _Section(
                        title: 'About me',
                        children: [
                          Text(
                            player.bio!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(height: 1.4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    _StatsCard(playerId: player.id),
                    const SizedBox(height: 12),
                    _AccountCard(firebaseReady: firebaseReady, user: user),

                    // ═══ TESTING ONLY — see lib/testing_tools.dart ══════════════════════
                    if (kShowTestingTools) ...[
                      const SizedBox(height: 12),
                      const _TestingToolsCard(),
                    ],
                    // ═══ END TESTING ONLY ═══════════════════════════════════════════════
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small pencil button on the banner.
class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg.withValues(alpha: 0.55),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded, size: 16, color: AppColors.text),
              SizedBox(width: 6),
              Text(
                'Edit profile',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Name, @username and status — who you are, in three lines.
class _Identity extends StatelessWidget {
  const _Identity({required this.player, required this.user});

  final PlayerIdentity player;
  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: AppColors.textMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (player.handle != null) ...[
              Text('@${player.handle}', style: muted),
              const SizedBox(width: 10),
            ],
            Icon(
              user == null ? Icons.phone_android_rounded : Icons.verified_rounded,
              size: 14,
              color: user == null ? AppColors.textMuted : AppColors.success,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                user == null ? 'On this device' : 'Signed in',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        if (player.status != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Flexible(child: Text(player.status!, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Lifetime numbers: what you hold and how far you have run for it.
class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territories = ref.watch(
      trackingControllerProvider.select((s) => s.territories),
    );
    final runs = ref.watch(runsProvider).value ?? const [];
    final mine = territories.where((t) => t.ownerId == playerId);
    final groundM2 = mine.fold<double>(0, (sum, t) => sum + t.areaM2);
    final distanceM = runs.fold<double>(0, (sum, r) => sum + r.distanceM);

    return _Section(
      title: 'Stats',
      children: [
        StatGrid(
          columns: 2,
          children: [
            StatTile(
              label: 'Ground',
              value: formatArea(groundM2),
              valueColor: AppColors.accent,
            ),
            StatTile(label: 'Plots', value: '${mine.length}'),
            StatTile(label: 'Runs', value: '${runs.length}'),
            StatTile(label: 'Distance', value: formatDistance(distanceM)),
          ],
        ),
      ],
    );
  }
}

/// Signed out: the ways in. Signed in: who as, and the way out.
class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.firebaseReady, required this.user});

  final bool firebaseReady;
  final User? user;

  void _openSignIn(BuildContext context, EmailMode mode) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => SignInScreen(initialMode: mode)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.textMuted,
      height: 1.35,
    );

    // Nothing about accounts is offered on a build where Firebase never started; the game is
    // fully playable without one, and a control that cannot work is worse than none.
    if (!firebaseReady) {
      return _Section(
        title: 'Playing offline',
        children: [
          Text('Your runs and territory are stored on this device.', style: muted),
        ],
      );
    }

    final signedIn = user;
    if (signedIn == null) {
      return _Section(
        title: 'Account',
        children: [
          Text(
            'Sign in to keep your ground across devices and appear on the leaderboard '
            'alongside other players.',
            style: muted,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _openSignIn(context, EmailMode.signIn),
                  child: const Text('Sign in'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openSignIn(context, EmailMode.createAccount),
                  child: const Text('Create account'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final provider = ref.read(authServiceProvider).providerLabel;
    return _Section(
      title: 'Account',
      children: [
        _InfoRow(label: 'Signed in with', value: provider ?? 'Account'),
        if (signedIn.email != null) _InfoRow(label: 'Email', value: signedIn.email!),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                    'Your ground stays with your account. Sign back in any time to '
                    'pick it up again.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await ref.read(authServiceProvider).signOut();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out')),
              );
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ TESTING ONLY — see lib/testing_tools.dart ═══════════════════════════════════════════════
/// Clears all claimed ground so a loop can be captured again. Hidden when
/// `kShowTestingTools` is false.
class _TestingToolsCard extends ConsumerWidget {
  const _TestingToolsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: 'Testing tools',
      children: [
        Text(
          'Clears all claimed ground and restores the rivals to how they started, so you '
          'can run and capture the same area again. Your runs are kept.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
            ),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset captured ground'),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset captured ground?'),
                  content: const Text(
                    'All claimed ground is removed and the rivals are restored. '
                    'This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              final done = await ref
                  .read(trackingControllerProvider.notifier)
                  .resetGroundForTesting();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    done
                        ? 'Ground reset — go capture it again'
                        : 'Finish or discard the current run first',
                  ),
                ),
              );
              if (done) context.go('/home');
            },
          ),
        ),
      ],
    );
  }
}
// ═══ END TESTING ONLY ═════════════════════════════════════════════════════════════════════════

/// A titled card: one group of the profile.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

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
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
