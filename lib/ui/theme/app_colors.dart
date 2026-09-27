import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color bg = Color(0xFF0B0D10);
  static const Color surface = Color(0xFF15181D);
  static const Color surfaceHigh = Color(0xFF1E232A);
  static const Color outline = Color(0xFF2A3038);
  static const Color text = Color(0xFFF4F6F8);
  static const Color textMuted = Color(0xFF9AA3AE);

  static const Color accent = Color(0xFFC6F432);
  static const Color onAccent = Color(0xFF0B0D10);

  static const Color danger = Color(0xFFFF5A5F);
  static const Color warning = Color(0xFFFFB547);
  static const Color success = Color(0xFF3DDC97);

  static const Color gold = Color(0xFFFFD166);
  static const Color silver = Color(0xFFC9D1DA);
  static const Color bronze = Color(0xFFE0A071);
}

abstract final class AppFonts {
  static const String body = 'Inter';

  static const String display = 'SpaceGrotesk';
}
