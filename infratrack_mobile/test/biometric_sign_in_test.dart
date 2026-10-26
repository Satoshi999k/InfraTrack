import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infatrack/biometric_sign_in.dart';
import 'package:infatrack/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/appearance_preferences.dart';
import 'package:infatrack/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login offers biometric sign-in when the user enabled it', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = BiometricSignInService(credentialStore: _MemoryStore());
    await service.enable(
      email: 'resident@example.test',
      password: 'test-password',
    );

    await tester.pumpWidget(
      MaterialApp(home: LoginPage(biometricService: service)),
    );
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

  test(
    'wrong login credentials do not invalidate the signed-in session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final originalClientFactory = ApiService.httpClientFactory;
      final expiredSessionCount = ApiService.sessionExpired.value;
      var loginCount = 0;
      ApiService.httpClientFactory = () => MockClient((request) async {
        expect(request.url.path, endsWith('/mobile/auth/login'));
        loginCount++;
        if (loginCount == 1) {
          return http.Response(
            jsonEncode({
              'token': 'active-session-test-token',
              'user': {'id': 42, 'name': 'Test Resident'},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'error': 'Invalid email or password'}),
          401,
        );
      });

      try {
        await ApiService.login('resident@example.test', 'correct-password');
        await expectLater(
          ApiService.login('resident@example.test', 'wrong-password'),
          throwsA(isA<ApiException>()),
        );

        expect(ApiService.sessionExpired.value, expiredSessionCount);
        expect(ApiService.consumeSessionNotice(), isNull);
        expect(ApiService.isSignedIn, isTrue);
      } finally {
        ApiService.httpClientFactory = originalClientFactory;
        await ApiService.signOutForExpiredSession();
      }
    },
  );

  test(
    'an unauthorized authenticated request still expires the session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final originalClientFactory = ApiService.httpClientFactory;
      final expiredSessionCount = ApiService.sessionExpired.value;
      ApiService.httpClientFactory = () => MockClient((request) async {
        if (request.url.path.endsWith('/mobile/auth/login')) {
          return http.Response(
            jsonEncode({
              'token': 'expired-session-test-token',
              'user': {'id': 42, 'name': 'Test Resident'},
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'error': 'Session expired'}), 401);
      });

      try {
        await ApiService.login('resident@example.test', 'test-password');
        await expectLater(ApiService.reports(), throwsA(isA<ApiException>()));

        expect(ApiService.sessionExpired.value, expiredSessionCount + 1);
        expect(
          ApiService.consumeSessionNotice(),
          contains('session has expired'),
        );
        expect(ApiService.isSignedIn, isFalse);
      } finally {
        ApiService.httpClientFactory = originalClientFactory;
        await ApiService.signOutForExpiredSession();
      }
    },
  );

  testWidgets('biometric enrollment password can be shown while typing', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'biometric-visibility-test-token',
            'user': {
              'id': 42,
              'name': 'Test Resident',
              'email': 'resident@example.test',
              'role': 'resident',
            },
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/preferences')) {
        return http.Response(
          jsonEncode({
            'preferences': {
              'allowNotifications': true,
              'showLocationOnReports': true,
            },
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(
        MaterialApp(
          home: PrivacySecurityPage(
            biometricService: _AvailableBiometricService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final biometricSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Biometric sign-in'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(biometricSwitch);
      await tester.tap(biometricSwitch);
      await tester.pumpAndSettle();

      final passwordField = find.byType(TextField);
      expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(tester.widget<TextField>(passwordField).obscureText, isFalse);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await ApiService.signOutForExpiredSession();
    }
  });

  test(
    'biometric enrollment only belongs to the account that enabled it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = _MemoryStore();
      final service = BiometricSignInService(credentialStore: store);
      await service.enable(
        email: 'first@example.test',
        password: 'first-password',
      );

      expect(await service.isEnabledFor('first@example.test'), isTrue);
      expect(await service.isEnabledFor('second@example.test'), isFalse);

      await service.disableIfAccountMismatch('second@example.test');

      expect(await service.isEnabled, isFalse);
      expect(store.values, isEmpty);
    },
  );

  test('same account sign-in preserves biometric enrollment', () async {
    SharedPreferences.setMockInitialValues({});
    final service = BiometricSignInService(credentialStore: _MemoryStore());
    await service.enable(
      email: 'resident@example.test',
      password: 'test-password',
    );

    await service.disableIfAccountMismatch('RESIDENT@example.test');

    expect(await service.isEnabledFor('resident@example.test'), isTrue);
  });

  testWidgets('security settings use biometric sign-in instead of app lock', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: PrivacySecurityPage()));
    await tester.pumpAndSettle();

    expect(find.text('Biometric sign-in'), findsOneWidget);
    expect(find.text('Biometric app lock'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy and security text is readable in dark mode', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const appearance = InfraAppearance(theme: 'dark');
    final darkTheme = buildInfraTheme(appearance, Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const PrivacySecurityPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Show location on reports')).style?.color,
      darkTheme.colorScheme.onSurface,
    );
    expect(
      tester.widget<Text>(find.text('Change password')).style?.color,
      darkTheme.colorScheme.onSurface,
    );
    expect(
      tester
          .widget<Text>(find.text('Helps the city locate reported issues'))
          .style
          ?.color,
      darkTheme.inputDecorationTheme.hintStyle?.color,
    );

    final info = tester.widget<Container>(
      find.byKey(const ValueKey('privacy-security-info')),
    );
    expect(
      (info.decoration! as BoxDecoration).color,
      darkTheme.colorScheme.surface,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a different account sees biometric sign-in turned off', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = BiometricSignInService(credentialStore: _MemoryStore());
    await service.enable(
      email: 'first@example.test',
      password: 'first-password',
    );
    final originalUser = ApiService.currentUser;
    ApiService.currentUser = {'email': 'second@example.test'};

    try {
      await tester.pumpWidget(
        MaterialApp(home: PrivacySecurityPage(biometricService: service)),
      );
      await tester.pumpAndSettle();

      final biometricTile = find.ancestor(
        of: find.text('Biometric sign-in'),
        matching: find.byType(ListTile),
      );
      final toggle = tester.widget<Switch>(
        find.descendant(of: biometricTile, matching: find.byType(Switch)),
      );
      expect(toggle.value, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      ApiService.currentUser = originalUser;
    }
  });
}

class _AvailableBiometricService extends BiometricSignInService {
  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<bool> get isEnabled async => false;

  @override
  Future<bool> authenticate(String reason) async => true;
}

class _MemoryStore implements BiometricCredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
