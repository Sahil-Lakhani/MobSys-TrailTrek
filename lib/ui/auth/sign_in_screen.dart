import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../data/providers.dart';
import '../theme/app_colors.dart';

/// The way in, and the only screen a signed-out player can reach.
///
/// ClaimTrek is a shared map: every plot belongs to someone, and a steal has to reach the
/// person it was taken from. That needs an account, so the app opens here until there is one.
/// Leaving is the router's job — it moves on the moment the account appears.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;

  /// Reads a provider's future while keeping it subscribed.
  ///
  /// A provider nobody listens to is paused, and a sign-in rebuilds the player identity under
  /// it — a bare `read(...future)` at that moment can wait forever.
  static Future<T> _readLive<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
    Future<T> Function() future,
  ) async {
    final keepAlive = container.listen(provider, (_, _) {});
    try {
      return await future();
    } finally {
      keepAlive.close();
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    // The app-wide container rather than this screen's `ref`: the router swaps this screen out
    // the instant the account appears, and the adoption below must still finish after it has.
    final container = ProviderScope.containerOf(context, listen: false);

    try {
      final user = await container.read(authServiceProvider).signInWithGoogle();

      // Null means the user backed out of the Google sheet. Nothing went wrong, so nothing
      // should be said — showing an error here would blame them for changing their mind.
      if (user == null) return;

      await container
          .read(userDirectoryProvider)
          .upsertOnSignIn(
            uid: user.uid,
            displayName: user.displayName,
            email: user.email,
            photoUrl: user.photoURL,
          );

      // Ground captured on this phone before the account existed is filed under a local id;
      // it moves to the account now rather than on some later rebuild.
      final player = await _readLive(
        container,
        playerIdentityProvider,
        () => container.read(playerIdentityProvider.future),
      );
      final previousOwnerId = player.localId;
      player.bindTo(
        uid: user.uid,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );

      final sync = await _readLive(
        container,
        syncServiceProvider,
        () => container.read(syncServiceProvider.future),
      );
      await sync.onSignedIn(previousOwnerId: previousOwnerId);
    } catch (e) {
      if (mounted) setState(() => _error = _describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Something a person can act on, rather than an exception's `toString`.
  static String _describe(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
          return 'No connection. Check your internet and try again.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'missing-id-token':
          return error.message ??
              'Google sign-in is not set up for this build.';
      }
      return error.message ?? 'Sign-in failed. Please try again.';
    }
    if (error is UnsupportedError) {
      return 'Google sign-in is not available on this device.';
    }
    return 'Sign-in failed. Please try again.';
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
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _AppMark(),
                                const Spacer(),
                                Text(
                                  'ClaimTrek',
                                  style: theme.textTheme.displayMedium
                                      ?.copyWith(
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
                                  text: 'Steal ground from friends and top the board',
                                ),
                                const SizedBox(height: 32),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _error == null
                                      ? const SizedBox.shrink()
                                      : Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 14,
                                          ),
                                          child: _ErrorNote(message: _error!),
                                        ),
                                ),
                                _GoogleButton(busy: _busy, onPressed: _signIn),
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    'We use your Google name and photo on the\n'
                                    'leaderboard. Your email stays private.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textMuted,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

/// Google's own button convention: white, their mark, "Continue with Google".
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.bg,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.85),
          disabledForegroundColor: AppColors.bg,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: busy
              ? const Row(
                  key: ValueKey('busy'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.bg,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Signing in…'),
                  ],
                )
              : const Row(
                  key: ValueKey('idle'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(size: Size(22, 22), painter: _GoogleMark()),
                    SizedBox(width: 12),
                    Text('Continue with Google'),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.text, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// The four-colour Google "G", drawn so no image asset is needed.
class _GoogleMark extends CustomPainter {
  const _GoogleMark();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    const deg = math.pi / 180;
    // Clockwise from the right-hand bar, the way the mark is built.
    canvas.drawArc(
      rect,
      -10 * deg,
      55 * deg,
      false,
      arc(const Color(0xFF4285F4)),
    );
    canvas.drawArc(
      rect,
      45 * deg,
      90 * deg,
      false,
      arc(const Color(0xFF34A853)),
    );
    canvas.drawArc(
      rect,
      135 * deg,
      90 * deg,
      false,
      arc(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      225 * deg,
      95 * deg,
      false,
      arc(const Color(0xFFEA4335)),
    );

    // The crossbar of the G.
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2,
        size.height / 2 - stroke / 2,
        size.width / 2 - stroke / 4,
        stroke,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleMark oldDelegate) => false;
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
