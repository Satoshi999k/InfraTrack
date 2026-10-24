import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/appearance_preferences.dart';
import 'package:infatrack/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('appearance settings persist and restore all preferences', () async {
    SharedPreferences.setMockInitialValues({});
    const appearance = InfraAppearance(
      theme: 'dark',
      accent: 'violet',
      typeface: 'poppins',
      textSize: 'large',
      corners: 'soft',
      highContrast: true,
    );

    await saveInfraAppearance(appearance);
    infraAppearance.value = const InfraAppearance();
    await loadInfraAppearance();

    expect(infraAppearance.value.theme, 'dark');
    expect(infraAppearance.value.accent, 'violet');
    expect(infraAppearance.value.typeface, 'poppins');
    expect(infraAppearance.value.textSize, 'large');
    expect(infraAppearance.value.corners, 'soft');
    expect(infraAppearance.value.highContrast, isTrue);
  });

  testWidgets('appearance settings update and save theme and text size', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    infraAppearance.value = const InfraAppearance();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInfraTheme(infraAppearance.value, Brightness.light),
        darkTheme: buildInfraTheme(infraAppearance.value, Brightness.dark),
        home: const AppearanceSettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(infraAppearance.value.theme, 'dark');

    await tester.scrollUntilVisible(
      find.text('Large'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(infraAppearance.value.textSize, 'large');

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(appearancePreferenceKey),
      contains('"theme":"dark"'),
    );
    expect(
      preferences.getString(appearancePreferenceKey),
      contains('"textSize":"large"'),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('typeface choices use equal-width tiles', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    infraAppearance.value = const InfraAppearance();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInfraTheme(infraAppearance.value, Brightness.light),
        darkTheme: buildInfraTheme(infraAppearance.value, Brightness.dark),
        home: const AppearanceSettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    final widths = tester.getSize(find.byType(ChoiceChip).first).width;
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(tester.getSize(find.byWidget(chip)).width, closeTo(widths, 0.1));
    }
    expect(find.byType(ChoiceChip), findsNWidgets(8));
    expect(
      tester.widget<Text>(find.text('Roboto')).style?.fontFamily,
      startsWith('Roboto'),
    );
    expect(
      tester.widget<Text>(find.text('Poppins')).style?.fontFamily,
      startsWith('Poppins'),
    );
    final systemPreview = find.descendant(
      of: find.byType(ChoiceChip).at(1),
      matching: find.text('System'),
    );
    expect(tester.widget<Text>(systemPreview).style?.inherit, isFalse);
    expect(tester.widget<Text>(systemPreview).style?.fontFamily, isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('appearance option cards share the same full width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    infraAppearance.value = const InfraAppearance();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInfraTheme(infraAppearance.value, Brightness.light),
        darkTheme: buildInfraTheme(infraAppearance.value, Brightness.dark),
        home: const AppearanceSettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    final themeCard = find.byKey(const ValueKey('appearance-section-Theme'));
    final accentCard = find.byKey(
      const ValueKey('appearance-section-Accent color'),
    );
    final typefaceCard = find.byKey(
      const ValueKey('appearance-section-Typeface'),
    );
    final expectedWidth = tester.getSize(themeCard).width;

    expect(tester.getSize(accentCard).width, expectedWidth);
    expect(tester.getSize(typefaceCard).width, expectedWidth);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('selected typeface styles previews and app text consistently', () {
    final preview = appearanceFontStyle(
      'roboto',
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
    final theme = buildInfraTheme(
      const InfraAppearance(typeface: 'arial'),
      Brightness.light,
    );

    expect(preview.fontFamily, startsWith('Roboto'));
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Arial');
    expect(appearanceFontStyle('arial', const TextStyle()).fontFamily, 'Arial');
    expect(appearanceFontStyle('system', const TextStyle()).fontFamily, isNull);
  });

  test(
    'appearance themes provide distinct dark palette and selected accent',
    () {
      final dark = buildInfraTheme(
        const InfraAppearance(theme: 'dark', accent: 'violet'),
        Brightness.dark,
      );
      final light = buildInfraTheme(
        const InfraAppearance(accent: 'violet'),
        Brightness.light,
      );

      expect(
        dark.scaffoldBackgroundColor,
        isNot(light.scaffoldBackgroundColor),
      );
      expect(dark.colorScheme.primary, appearanceAccentColors['violet']);
      expect(dark.cardColor, isNot(light.cardColor));
    },
  );

  test('accent colors apply to themed buttons with readable foregrounds', () {
    for (final entry in appearanceAccentColors.entries) {
      final theme = buildInfraTheme(
        InfraAppearance(accent: entry.key),
        Brightness.light,
      );
      final filledStyle = theme.filledButtonTheme.style!;
      final textStyle = theme.textButtonTheme.style!;

      expect(theme.colorScheme.primary, entry.value);
      expect(filledStyle.backgroundColor?.resolve({}), entry.value);
      expect(textStyle.foregroundColor?.resolve({}), entry.value);
      expect(
        filledStyle.foregroundColor?.resolve({}),
        entry.value.computeLuminance() > 0.179
            ? const Color(0xFF071D24)
            : Colors.white,
      );
    }
  });

  test('high contrast strengthens card, input, and chip outlines', () {
    final normal = buildInfraTheme(const InfraAppearance(), Brightness.light);
    final highContrast = buildInfraTheme(
      const InfraAppearance(highContrast: true),
      Brightness.light,
    );
    final normalCardShape = normal.cardTheme.shape! as RoundedRectangleBorder;
    final highContrastCardShape =
        highContrast.cardTheme.shape! as RoundedRectangleBorder;

    expect(
      highContrastCardShape.side.width,
      greaterThan(normalCardShape.side.width),
    );
    expect(
      highContrast.inputDecorationTheme.enabledBorder!.borderSide.width,
      greaterThan(normal.inputDecorationTheme.enabledBorder!.borderSide.width),
    );
    expect(
      highContrast.chipTheme.side!.width,
      greaterThan(normal.chipTheme.side!.width),
    );
  });

  test('high contrast text and selected navigation meet readable contrast', () {
    for (final brightness in Brightness.values) {
      final theme = buildInfraTheme(
        const InfraAppearance(highContrast: true),
        brightness,
      );
      final background = brightness == Brightness.dark
          ? theme.cardColor
          : theme.scaffoldBackgroundColor;
      final foreground = theme.textTheme.bodyMedium!.color!;
      final hint = theme.inputDecorationTheme.hintStyle!.color!;
      final selectedNavigation = theme.navigationBarTheme.labelTextStyle!
          .resolve({WidgetState.selected})!
          .color!;

      expect(_contrastRatio(foreground, background), greaterThanOrEqualTo(7));
      expect(
        _contrastRatio(hint, theme.inputDecorationTheme.fillColor!),
        greaterThanOrEqualTo(7),
      );
      expect(
        _contrastRatio(selectedNavigation, background),
        greaterThanOrEqualTo(7),
      );
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
