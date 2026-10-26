import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:infatrack/api_service.dart';
import 'package:infatrack/biometric_sign_in.dart';
import 'package:infatrack/main.dart';

void main() {
  final originalHttpClientFactory = ApiService.httpClientFactory;

  tearDown(() {
    ApiService.httpClientFactory = originalHttpClientFactory;
  });

  testWidgets('forgot password opens the reset flow from login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(biometricService: _DisabledBiometricService()),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Forgot your password?'));
    await tester.tap(find.text('Forgot your password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.text('Send reset code'), findsOneWidget);
  });

  testWidgets('requests a code and submits a new password', (tester) async {
    final requests = <http.Request>[];
    ApiService.httpClientFactory = () => MockClient((request) async {
      requests.add(request);
      final response = request.url.path.endsWith('/request')
          ? {
              'message':
                  'If an account matches that email, a code will be sent.',
            }
          : {'ok': true};
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: PasswordResetPage(initialEmail: 'resident@example.com'),
      ),
    );
    await tester.tap(find.text('Send reset code'));
    await _pumpApiResponse(tester);

    expect(
      find.textContaining('a 6-digit code will arrive shortly'),
      findsOneWidget,
    );
    expect(find.text('6-DIGIT CODE'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '123456');
    await tester.enterText(find.byType(TextFormField).at(1), 'safe-pass-42');
    await tester.enterText(find.byType(TextFormField).at(2), 'safe-pass-42');
    await tester.ensureVisible(find.text('Reset password'));
    await tester.tap(find.text('Reset password'));
    await _pumpApiResponse(tester);

    expect(find.text('Password updated'), findsOneWidget);
    expect(requests, hasLength(2));
    expect(
      requests[0].url.path,
      endsWith('/mobile/auth/password-reset/request'),
    );
    expect(jsonDecode(requests[0].body), {'email': 'resident@example.com'});
    expect(
      requests[1].url.path,
      endsWith('/mobile/auth/password-reset/complete'),
    );
    expect(jsonDecode(requests[1].body), {
      'email': 'resident@example.com',
      'code': '123456',
      'newPassword': 'safe-pass-42',
    });
  });
}

Future<void> _pumpApiResponse(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame += 1) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

class _DisabledBiometricService extends BiometricSignInService {
  @override
  Future<bool> get isEnabled async => false;
}
