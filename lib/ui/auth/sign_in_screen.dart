import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../theme/app_colors.dart';

/// The way in. One button, because there is one way to sign in.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();

      // Null means the user backed out of the Google sheet. Nothing went wrong, so nothing
      // should be said — showing an error here would blame them for changing their mind.
      if (user == null) return;

      await ref
          .read(userDirectoryProvider)
          .upsertOnSignIn(
            uid: user.uid,
            displayName: user.displayName,
            email: user.email,
            photoUrl: user.photoURL,
          );

      // Bind here rather than waiting for the auth stream to reach the identity provider, so
      // the ground captured before signing in is adopted now and not on some later rebuild.
      final player = await ref.read(playerIdentityProvider.future);
      final previousOwnerId = player.localId;
      player.bindTo(
        uid: user.uid,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );

      final sync = await ref.read(syncServiceProvider.future);
      await sync.onSignedIn(previousOwnerId: previousOwnerId);

      // Leave, or a successful sign-in looks exactly like a failed one: the spinner stops and
      // the same button is still sitting there.
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _ContourPainter()),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                blurRadius: 28,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.flag_rounded,
                            size: 30,
                            color: AppColors.onAccent,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'ClaimTrek',
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontSize: 52,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Run a loop. Claim the ground inside it.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const _Feature(
                          icon: Icons.directions_run_rounded,
                          text: 'Run any closed loop, anywhere',
                        ),
                        const _Feature(
                          icon: Icons.hexagon_rounded,
                          text: 'Everything inside becomes yours',
                        ),
                        const _Feature(
                          icon: Icons.emoji_events_rounded,
                          text: 'Steal ground and top the board',
                        ),
                        const SizedBox(height: 36),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _signIn,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.bg,
                              minimumSize: const Size.fromHeight(56),
                            ),
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.bg,
                                    ),
                                  )
                                : const Text(
                                    'G',
                                    style: TextStyle(
                                      fontFamily: AppFonts.display,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 20,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                            label: Text(
                              _busy ? 'Signing in…' : 'Continue with Google',
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        if (context.canPop()) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: () => context.pop(),
                              child: const Text('Not now'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Topographic contour lines behind a lime glow: a map, abstracted.
///
/// Painted rather than shipped as an image so it is sharp at any density and costs nothing
/// in the bundle.
class _ContourPainter extends CustomPainter {
  const _ContourPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glowCentre = Offset(size.width * 0.85, size.height * 0.18);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                AppColors.accent.withValues(alpha: 0.22),
                AppColors.accent.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: glowCentre, radius: size.width * 0.9),
            ),
    );

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Nested wobbly rings around the glow, fading outward like elevation bands.
    for (var i = 1; i <= 14; i++) {
      final r = i * size.width * 0.075;
      line.color = AppColors.accent.withValues(alpha: 0.16 * (1 - i / 16));
      final path = Path();
      const steps = 72;
      for (var s = 0; s <= steps; s++) {
        final a = s / steps * 2 * math.pi;
        final wobble =
            1 +
            0.08 * math.sin(a * 3 + i * 0.7) +
            0.05 * math.cos(a * 5 - i * 0.4);
        final p = glowCentre + Offset(math.cos(a), math.sin(a)) * r * wobble;
        s == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_ContourPainter oldDelegate) => false;
}
