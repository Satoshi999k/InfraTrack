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
}
