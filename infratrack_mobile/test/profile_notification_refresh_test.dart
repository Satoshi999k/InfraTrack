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
    'profile unread count refreshes when a new notification arrives',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final originalClientFactory = ApiService.httpClientFactory;
      var notificationFetchCount = 0;
      ApiService.httpClientFactory = () => MockClient((request) async {
        if (request.url.path.endsWith('/mobile/auth/login')) {
          return http.Response(
            jsonEncode({
              'token': 'profile-notification-test-token',
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
                'name': 'Test Resident',
                'verification': 'Verified',
              },
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/mobile/reports')) {
          return http.Response(jsonEncode({'reports': []}), 200);
        }

        if (request.url.path.endsWith('/mobile/notifications')) {
          notificationFetchCount++;
          final count = notificationFetchCount == 1 ? 1 : 2;
          return http.Response(
            jsonEncode({
              'notifications': List.generate(
                count,
                (index) => {
                  'id': index + 1,
                  'type': 'account',
                  'title': 'Account update ${index + 1}',
                  'message': 'Account notification',
                  'created_at': '2026-10-20T10:00:00.000Z',
                  'read_at': null,
                },
              ),
            }),
            200,
          );
        }

        return http.Response('Not found', 404);
      });

      try {
        await ApiService.login('resident@example.test', 'test-password');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ProfilePage())),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 unread'), findsOneWidget);

        await tester.pump(const Duration(seconds: 30));
        await tester.pumpAndSettle();

        expect(notificationFetchCount, greaterThanOrEqualTo(2));
        expect(find.text('2 unread'), findsOneWidget);
      } finally {
        ApiService.httpClientFactory = originalClientFactory;
        await ApiService.signOutForExpiredSession();
      }
    },
  );
}
