import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The one theme ClaimTrek ships.
///
/// Built from a hand-picked scheme rather than a seed: a seeded scheme tints every surface
/// with the accent, and lime-tinted greys look ill rather than sporty.
abstract final class AppTheme {
  static const double radius = 20;

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: Color(0xFF2B3510),
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      secondaryContainer: AppColors.surfaceHigh,
      onSecondaryContainer: AppColors.text,
      tertiary: AppColors.warning,
      onTertiary: AppColors.onAccent,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: Color(0xFF3A1719),
      onErrorContainer: Color(0xFFFFB3B5),
      surface: AppColors.bg,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      surfaceContainerLowest: AppColors.bg,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: Color(0xFF4A525C),
      outlineVariant: AppColors.outline,
      inverseSurface: AppColors.text,
      onInverseSurface: AppColors.bg,
      inversePrimary: Color(0xFF5A7300),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = _textTheme(base.textTheme);

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        foregroundColor: AppColors.text,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.surfaceHigh,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          side: const BorderSide(color: AppColors.outline, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        hintStyle: text.bodyLarge?.copyWith(color: AppColors.textMuted),
        labelStyle: text.bodyLarge?.copyWith(color: AppColors.textMuted),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: AppColors.accent),
        helperStyle: text.bodySmall?.copyWith(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: Color(0x55C6F432),
        selectionHandleColor: AppColors.accent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textMuted,
        textColor: AppColors.text,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: text.bodySmall?.copyWith(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.text),
        actionTextColor: AppColors.accent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent,
        disabledColor: AppColors.surface,
        side: const BorderSide(color: AppColors.outline),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge?.copyWith(color: AppColors.text),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: AppColors.onAccent,
        ),
        checkmarkColor: AppColors.onAccent,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.outline,
        circularTrackColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.outline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    TextStyle? display(TextStyle? s, double size, FontWeight weight) =>
        s?.copyWith(
          fontFamily: AppFonts.display,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: -0.5,
          height: 1.1,
          color: AppColors.text,
        );

    return base
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text)
        .copyWith(
          displayLarge: display(base.displayLarge, 56, FontWeight.w700),
          displayMedium: display(base.displayMedium, 44, FontWeight.w700),
          displaySmall: display(base.displaySmall, 36, FontWeight.w700),
          headlineLarge: display(base.headlineLarge, 32, FontWeight.w700),
          headlineMedium: display(base.headlineMedium, 28, FontWeight.w700),
          headlineSmall: display(base.headlineSmall, 24, FontWeight.w600),
          titleLarge: display(base.titleLarge, 22, FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: AppColors.textMuted,
          ),
        );
  }

  /// Big, fixed-width numbers for stats: a counter that ticks must not shuffle its neighbours.
  ///
  /// Inter rather than the display face: Space Grotesk's quirky "1" reads as a letter at a
  /// glance, and a glance is all a runner gives the counter.
  static TextStyle number(double size, {Color color = AppColors.text}) =>
      TextStyle(
        fontFamily: AppFonts.body,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.02 * size,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
