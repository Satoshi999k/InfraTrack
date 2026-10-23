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
  final background = dark ? const Color(0xFF101B20) : const Color(0xFFF3EFE6);
  final surface = dark ? const Color(0xFF19282E) : Colors.white;
  final foreground = dark ? const Color(0xFFE7EFED) : const Color(0xFF17231F);
  final muted = dark ? const Color(0xFFB1C1BE) : const Color(0xFF5B6B67);
  final border = dark ? const Color(0xFF35474B) : const Color(0xFFDDD8CB);
  final radius = switch (appearance.corners) {
    'square' => 8.0,
    'soft' => 24.0,
    _ => 16.0,
  };
  final contrastForeground = appearance.highContrast
      ? (dark ? Colors.white : const Color(0xFF071D24))
      : foreground;
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
          onPrimary: Colors.white,
          secondary: accent,
          onSurface: contrastForeground,
          outline: appearance.highContrast ? muted : border,
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
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : null,
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
