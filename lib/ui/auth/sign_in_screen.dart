import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_service.dart';
import '../../data/providers.dart';
import '../theme/app_colors.dart';
import 'sign_in_flow.dart';

/// Which half of the email form is showing.
enum EmailMode { signIn, createAccount }

/// The way in: Google in one tap, or an email account.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({this.initialMode = EmailMode.signIn, super.key});

  final EmailMode initialMode;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  late EmailMode _mode = widget.initialMode;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _creating => _mode == EmailMode.createAccount;

  /// Runs one sign-in attempt, then completes it and leaves.
  ///
  /// [attempt] returns null when the player backed out, which is not an error.
  Future<void> _run(
    Future<User?> Function() attempt, {
    String? onNull,
    String? handle,
  }) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await attempt();
      if (user == null) {
        if (mounted && onNull != null) setState(() => _error = onNull);
        return;
      }
      await completeSignIn(ref, user, handle: handle);

      // Leave, or a successful sign-in looks exactly like a failed one: the spinner stops and
      // the same buttons are still sitting there.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed in as ${user.displayName ?? user.email}')),
      );
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        context.go('/profile');
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _google() => _run(
    () => ref.read(authServiceProvider).signInWithGoogle(),
    // Google reports a failed account check the same way as backing out, so both get a
    // sentence rather than silence — silence is what made a failure look like success.
    onNull: 'Google sign-in did not finish. If you did not cancel it, see the note '
        'about SHA-1 in the project summary.',
  );

  void _submitEmail() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = ref.read(authServiceProvider);
    _run(
      () => _creating
          ? auth.signUpWithEmail(
              username: _username.text,
              email: _email.text,
              password: _password.text,
            )
          : auth.signInWithEmail(email: _email.text, password: _password.text),
      handle: _creating ? _username.text : null,
    );
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Type your email above first, then tap "Forgot password?".');
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = describeAuthError(e));
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
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).canPop()
                                    ? Navigator.of(context).pop()
                                    : context.go('/profile'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _creating ? 'Create your account' : 'Welcome back',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Carry your ground between devices and race other players '
                        'on the leaderboard.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Option 1: Google ─────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _google,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.bg,
                            minimumSize: const Size.fromHeight(54),
                          ),
                          icon: const Text(
                            'G',
                            style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          label: const Text('Continue with Google'),
                        ),
                      ),

                      const _OrDivider(),

                      // ── Option 2: email ──────────────────────────────────────────
                      SegmentedButton<EmailMode>(
                        segments: const [
                          ButtonSegment(
                            value: EmailMode.signIn,
                            label: Text('Sign in'),
                          ),
                          ButtonSegment(
                            value: EmailMode.createAccount,
                            label: Text('Create account'),
                          ),
                        ],
                        selected: {_mode},
                        showSelectedIcon: false,
                        onSelectionChanged: _busy
                            ? null
                            : (s) => setState(() {
                                _mode = s.first;
                                _error = null;
                              }),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _form,
                        child: Column(
                          children: [
                            if (_creating) ...[
                              TextFormField(
                                controller: _username,
                                enabled: !_busy,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                ),
                                validator: (v) {
                                  final t = (v ?? '').trim();
                                  if (t.length < 2) return 'At least 2 characters';
                                  if (t.length > 30) return 'At most 30 characters';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _email,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              enabled: !_busy,
                              obscureText: !_showPassword,
                              autofillHints: [
                                _creating
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              textInputAction: _creating
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_creating) _submitEmail();
                              },
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _showPassword
                                      ? 'Hide password'
                                      : 'Show password',
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                ),
                              ),
                              validator: (v) => (v ?? '').length < 6
                                  ? 'At least 6 characters'
                                  : null,
                            ),
                            if (_creating) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirm,
                                enabled: !_busy,
                                obscureText: !_showPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submitEmail(),
                                decoration: const InputDecoration(
                                  labelText: 'Confirm password',
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
                                ),
                                validator: (v) => v != _password.text
                                    ? 'Passwords do not match'
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!_creating)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : _forgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        )
                      else
                        const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _submitEmail,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_creating ? 'Create account' : 'Sign in'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.text,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ],
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.outline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or use email', style: muted),
          ),
          const Expanded(child: Divider(color: AppColors.outline)),
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
