import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appearancePreferenceKey = 'infratrack.appearance';

const appearanceAccentColors = <String, Color>{
  'teal': Color(0xFF1B8A83),
  'blue': Color(0xFF2679D8),
  'emerald': Color(0xFF17885C),
  'violet': Color(0xFF7651C9),
  'amber': Color(0xFFA96D11),
  'rose': Color(0xFFCA3F5C),
};

@immutable
class InfraAppearance {
  const InfraAppearance({
    this.theme = 'light',
    this.accent = 'teal',
    this.typeface = 'inter',
    this.textSize = 'regular',
    this.corners = 'rounded',
    this.highContrast = false,
  });

  final String theme;
  final String accent;
  final String typeface;
  final String textSize;
  final String corners;
  final bool highContrast;

  InfraAppearance copyWith({
    String? theme,
    String? accent,
    String? typeface,
    String? textSize,
    String? corners,
    bool? highContrast,
  }) => InfraAppearance(
    theme: theme ?? this.theme,
    accent: accent ?? this.accent,
    typeface: typeface ?? this.typeface,
    textSize: textSize ?? this.textSize,
    corners: corners ?? this.corners,
    highContrast: highContrast ?? this.highContrast,
  );

  Map<String, Object> toJson() => {
    'theme': theme,
    'accent': accent,
    'typeface': typeface,
    'textSize': textSize,
    'corners': corners,
    'highContrast': highContrast,
  };

  static InfraAppearance fromJson(Map<String, dynamic> value) =>
      InfraAppearance(
        theme: _choice(value['theme'], const [
          'light',
          'dark',
          'system',
        ], 'light'),
        accent: _choice(
          value['accent'],
          appearanceAccentColors.keys.toList(),
          'teal',
        ),
        typeface: _choice(value['typeface'], const [
          'inter',
          'system',
          'arial',
          'roboto',
          'lato',
          'open-sans',
          'poppins',
          'nunito',
        ], 'inter'),
        textSize: _choice(value['textSize'], const [
          'compact',
          'regular',
          'large',
        ], 'regular'),
        corners: _choice(value['corners'], const [
          'square',
          'rounded',
          'soft',
        ], 'rounded'),
        highContrast: value['highContrast'] == true,
      );
}

final infraAppearance = ValueNotifier(const InfraAppearance());

String _choice(Object? value, List<String> allowed, String fallback) =>
    value is String && allowed.contains(value) ? value : fallback;

Future<void> loadInfraAppearance() async {
  final preferences = await SharedPreferences.getInstance();
  final saved = preferences.getString(appearancePreferenceKey);
  if (saved == null) return;

  try {
    final decoded = jsonDecode(saved);
    if (decoded is Map<String, dynamic>) {
      infraAppearance.value = InfraAppearance.fromJson(decoded);
    }
  } on FormatException {
    await preferences.remove(appearancePreferenceKey);
  }
}

Future<void> saveInfraAppearance(InfraAppearance appearance) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(
    appearancePreferenceKey,
    jsonEncode(appearance.toJson()),
  );
  infraAppearance.value = appearance;
}

ThemeData buildInfraTheme(InfraAppearance appearance, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final accent = appearanceAccentColors[appearance.accent]!;
  final background = dark ? const Color(0xFF091E29) : Colors.white;
  final surface = dark ? const Color(0xFF123643) : Colors.white;
  final elevatedSurface = dark
      ? const Color(0xFF173F4D)
      : const Color(0xFFF7F9FA);
  final foreground = dark ? const Color(0xFFEAF6F4) : const Color(0xFF17231F);
  final muted = appearance.highContrast
      ? (dark ? const Color(0xFFE3EEEE) : const Color(0xFF344743))
      : (dark ? const Color(0xFFB2C9CC) : const Color(0xFF5B6B67));
  final border = appearance.highContrast
      ? (dark ? const Color(0xFF789399) : const Color(0xFF667772))
      : (dark ? const Color(0xFF345A63) : const Color(0xFFE0E5E7));
  final borderWidth = appearance.highContrast ? 2.0 : 1.0;
  final radius = switch (appearance.corners) {
    'square' => 8.0,
    'soft' => 24.0,
    _ => 16.0,
  };
  final contrastForeground = appearance.highContrast
      ? (dark ? Colors.white : const Color(0xFF071D24))
      : foreground;
  final onAccent = accent.computeLuminance() > 0.179
      ? const Color(0xFF071D24)
      : Colors.white;
  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: accent,
          onPrimary: onAccent,
          secondary: accent,
          onSecondary: onAccent,
          secondaryContainer: dark ? accent.withValues(alpha: 0.18) : null,
          surface: surface,
          onSurface: contrastForeground,
          outline: border,
          outlineVariant: border,
        ),
  );
  final textTheme = appearanceTextTheme(
    appearance.typeface,
    baseTheme.textTheme,
  );

  return baseTheme.copyWith(
    scaffoldBackgroundColor: background,
    canvasColor: background,
    cardColor: surface,
    dividerColor: appearance.highContrast ? muted : border,
    primaryColor: accent,
    textTheme: textTheme.apply(
      bodyColor: contrastForeground,
      displayColor: contrastForeground,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: contrastForeground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: border, width: borderWidth),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: elevatedSurface,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: border, width: borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(
          color: accent,
          width: appearance.highContrast ? 3 : 2,
        ),
      ),
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: border, width: borderWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: appearance.highContrast
              ? BorderSide(color: border, width: borderWidth)
              : BorderSide.none,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? const Color(0xFF1B3D49) : const Color(0xFFE8E2D7),
      selectedColor: accent.withValues(
        alpha: appearance.highContrast ? 0.24 : (dark ? 0.18 : 0.12),
      ),
      checkmarkColor: accent,
      side: BorderSide(color: border, width: borderWidth),
      labelStyle: TextStyle(
        color: contrastForeground,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: TextStyle(
        color: accent,
        fontWeight: FontWeight.w800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: dark
          ? const Color(0xFF0D2430)
          : Colors.white.withValues(alpha: 0.72),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: accent.withValues(alpha: dark ? 0.18 : 0.12),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? (appearance.highContrast ? contrastForeground : accent)
              : (dark ? const Color(0xFFB6C7C7) : const Color(0xFF5B6B67)),
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? (appearance.highContrast ? contrastForeground : accent)
              : (dark ? const Color(0xFFB6C7C7) : const Color(0xFF5B6B67)),
          size: 22,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent.withValues(alpha: 0.5)
            : (dark ? const Color(0xFF2B4651) : null),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: border, width: borderWidth),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : null,
      ),
      checkColor: WidgetStateProperty.all(onAccent),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : muted,
      ),
    ),
  );
}

TextTheme appearanceTextTheme(String typeface, TextTheme baseTextTheme) =>
    switch (typeface) {
      'system' => baseTextTheme,
      'arial' => baseTextTheme.apply(fontFamily: 'Arial'),
      'roboto' => GoogleFonts.robotoTextTheme(baseTextTheme),
      'lato' => GoogleFonts.latoTextTheme(baseTextTheme),
      'open-sans' => GoogleFonts.openSansTextTheme(baseTextTheme),
      'poppins' => GoogleFonts.poppinsTextTheme(baseTextTheme),
      'nunito' => GoogleFonts.nunitoTextTheme(baseTextTheme),
      _ => GoogleFonts.interTextTheme(baseTextTheme),
    };

TextStyle appearanceFontStyle(String typeface, TextStyle style) =>
    switch (typeface) {
      'system' => style,
      'arial' => style.copyWith(fontFamily: 'Arial'),
      'roboto' => GoogleFonts.roboto(textStyle: style),
      'lato' => GoogleFonts.lato(textStyle: style),
      'open-sans' => GoogleFonts.openSans(textStyle: style),
      'poppins' => GoogleFonts.poppins(textStyle: style),
      'nunito' => GoogleFonts.nunito(textStyle: style),
      _ => GoogleFonts.inter(textStyle: style),
    };
