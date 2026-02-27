import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? text,
    Color? muted,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      text: Color.lerp(text, other.text, t) ?? text,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const AppPalette lightPalette = AppPalette(
    background: Color(0xFFF5F7F6),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF15221B),
    muted: Color(0xFF5A6A61),
    accent: Color(0xFF0A7A52),
    success: Color(0xFF1F8A4C),
    warning: Color(0xFFA35F00),
    error: Color(0xFFB3261E),
  );

  static const AppPalette darkPalette = AppPalette(
    background: Color(0xFF0E1512),
    surface: Color(0xFF15211C),
    text: Color(0xFFE8F2EC),
    muted: Color(0xFFA5B9AF),
    accent: Color(0xFF5DC79D),
    success: Color(0xFF4CCF77),
    warning: Color(0xFFF2B34D),
    error: Color(0xFFFF897D),
  );

  static ThemeData light() => _buildTheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

  static ThemeData dark() => _buildTheme(
        brightness: Brightness.dark,
        palette: darkPalette,
      );

  static AppPalette fallbackFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkPalette : lightPalette;
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppPalette palette,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
    );
    final scheme = baseScheme.copyWith(
      primary: palette.accent,
      surface: palette.surface,
      onSurface: palette.text,
      error: palette.error,
      onError: brightness == Brightness.dark
          ? const Color(0xFF1C0907)
          : const Color(0xFFFFFFFF),
    );
    final onPrimary =
        ThemeData.estimateBrightnessForColor(palette.accent) == Brightness.dark
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF0D1914);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: Typography.material2021().black.apply(
            bodyColor: palette.text,
            displayColor: palette.text,
          ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.muted.withValues(alpha: 0.16)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        shadowColor: palette.muted.withValues(alpha: 0.16),
      ),
      dividerColor: palette.muted.withValues(alpha: 0.25),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        labelStyle: TextStyle(color: palette.muted),
        helperStyle: TextStyle(color: palette.muted),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: palette.muted.withValues(alpha: 0.42)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: palette.accent, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: onPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.accent,
          side: BorderSide(color: palette.accent.withValues(alpha: 0.55)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        thumbColor: palette.accent,
        inactiveTrackColor: palette.muted.withValues(alpha: 0.26),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.muted.withValues(alpha: 0.18),
      ),
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get appPalette {
    final theme = Theme.of(this);
    final extension = theme.extension<AppPalette>();
    if (extension != null) {
      return extension;
    }
    return AppTheme.fallbackFor(theme.brightness);
  }
}
