import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../common/glass_panel.dart';
import '../theme/app_colors.dart';
import '../tracking/tracking_map.dart' show parseHex;

/// A round avatar in the player's own colour, with their photo or initial.
///
/// The ring is the colour their ground is drawn in, so "which one on the map is me" is answered
/// by the button you tap to change it.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    required this.name,
    required this.colorHex,
    this.photoUrl,
    this.radius = 18,
    super.key,
  });

  final String name;
  final String colorHex;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colour = parseHex(colorHex, AppColors.accent);
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();

    return Container(
      padding: EdgeInsets.all(radius * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colour, width: radius * 0.12),
      ),
      child: CircleAvatar(
        radius: radius * 0.76,
        backgroundColor: colour.withValues(alpha: 0.22),
        foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.72,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// The way through to your profile, as a glass avatar that floats over the map.
///
/// Shown whether or not an account exists: the name and colour live on the profile screen and
/// both work offline.
class AccountAction extends ConsumerWidget {
  const AccountAction({this.glass = true, super.key});

  /// Glass chrome for over the map; plain for inside an app bar.
  final bool glass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerIdentityProvider).value;
    void open() => context.push('/profile');

    final avatar = player == null
        ? const Icon(Icons.person_outline_rounded, color: AppColors.text)
        : PlayerAvatar(
            name: player.name,
            colorHex: player.colorHex,
            photoUrl: player.photoUrl,
            radius: 16,
          );

    final button = Semantics(
      button: true,
      label: 'Profile',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: open,
          child: SizedBox.square(dimension: 48, child: Center(child: avatar)),
        ),
      ),
    );

    if (!glass) return button;
    return GlassPanel(
      shape: BoxShape.circle,
      padding: EdgeInsets.zero,
      child: button,
    );
  }
}
