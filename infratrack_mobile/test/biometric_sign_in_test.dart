import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login offers biometric sign-in when the user enabled it', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'biometric_sign_in_enabled': true});

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pump();

    expect(find.text('Sign in with biometrics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login does not offer biometric sign-in when it is disabled', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pump();

    expect(find.text('Sign in with biometrics'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
