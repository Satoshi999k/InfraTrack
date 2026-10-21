import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infatrack/api_service.dart';
import 'package:infatrack/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'profile layout stays readable on narrow screens and opens verification',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final originalClientFactory = ApiService.httpClientFactory;
      ApiService.httpClientFactory = () => MockClient((request) async {
        if (request.url.path.endsWith('/mobile/auth/login')) {
          return http.Response(
            jsonEncode({
              'token': 'profile-design-test-token',
              'user': {'id': 42, 'name': 'Test Resident'},
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/mobile/profile')) {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 42,
                'name': 'Alexandria Resident With A Long Name',
                'email': 'resident@example.test',
                'barangay': 'Barangay Central',
                'standing': 'Active',
                'verification': 'Pending ID match',
                'created_at': '2025-01-15T10:00:00.000Z',
              },
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/mobile/reports')) {
          return http.Response(jsonEncode({'reports': []}), 200);
        }

        if (request.url.path.endsWith('/mobile/notifications')) {
          return http.Response(jsonEncode({'notifications': []}), 200);
        }

        return http.Response('Not found', 404);
      });

      try {
        await ApiService.login('resident@example.test', 'test-password');
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ProfilePage())),
        );
        await tester.pumpAndSettle();

        expect(find.text('YOUR ACCOUNT'), findsOneWidget);
        expect(find.text('Edit profile'), findsOneWidget);
        expect(find.text('Active account'), findsOneWidget);
        expect(find.text('Verification in review'), findsOneWidget);
        expect(find.text('IN REVIEW'), findsOneWidget);
        expect(find.text('YOUR COMMUNITY IMPACT'), findsNothing);
        expect(tester.takeException(), isNull);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.pump();
        final verificationAction = find.text('Check status');
        await tester.ensureVisible(verificationAction);
        await tester.tap(verificationAction);
        await tester.pumpAndSettle();

        expect(find.text('Identity verification'), findsOneWidget);
        expect(find.text('PENDING REVIEW'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        ApiService.httpClientFactory = originalClientFactory;
        await ApiService.signOutForExpiredSession();
      }
    },
  );
}
