import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../common/glass_panel.dart';
import '../theme/app_colors.dart';
import '../tracking/tracking_map.dart' show parseHex;

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

class AccountAction extends ConsumerWidget {
  const AccountAction({this.glass = true, super.key});

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
