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

  testWidgets('home unread badge updates when a notification is read', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'notification-test-token',
            'user': {'id': 42, 'name': 'Test Resident'},
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/mobile/issues')) {
        return http.Response(jsonEncode({'issues': []}), 200);
      }

      if (request.url.path.endsWith('/mobile/reports')) {
        return http.Response(jsonEncode({'reports': []}), 200);
      }

      if (request.url.path.endsWith('/mobile/overview')) {
        return http.Response(jsonEncode({'overview': {}}), 200);
      }

      if (request.url.path.endsWith('/mobile/notifications')) {
        return http.Response(
          jsonEncode({
            'notifications': [
              {
                'id': 7,
                'type': 'account',
                'title': "You're verified - welcome to InfraTrack!",
                'message': 'Your account has been approved. You can now submit community reports.',
                'created_at': '2026-10-20T10:00:00.000Z',
                'read_at': null,
              },
            ],
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/mobile/notifications/7/read')) {
        return http.Response(jsonEncode({'ok': true}), 200);
      }

      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
      await tester.tap(find.text("You're verified - welcome to InfraTrack!"));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNothing);
      expect(
        tester
            .widget<Badge>(
              find.ancestor(
                of: find.byIcon(Icons.notifications_outlined),
                matching: find.byType(Badge),
              ),
            )
            .isLabelVisible,
        isFalse,
      );
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });

  testWidgets('notifications can all be marked read and filters show icons', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    var markAllRequestCount = 0;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'notification-test-token',
            'user': {'id': 42, 'name': 'Test Resident'},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/notifications')) {
        return http.Response(
          jsonEncode({
            'notifications': [
              {
                'id': 8,
                'type': 'report',
                'title': 'Report update',
                'message': 'Your report was approved.',
                'created_at': '2026-10-21T10:00:00.000Z',
                'read_at': null,
              },
              {
                'id': 9,
                'type': 'account',
                'title': 'Account verified',
                'message': 'Your account is verified.',
                'created_at': '2026-10-20T10:00:00.000Z',
                'read_at': '2026-10-20T11:00:00.000Z',
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/notifications/read-all')) {
        expect(request.method, 'PATCH');
        markAllRequestCount++;
        return http.Response(jsonEncode({'ok': true, 'updated': 1}), 200);
      }
      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(const MaterialApp(home: NotificationsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Mark all as read'), findsOneWidget);
      final filters = tester.widgetList<FilterChip>(find.byType(FilterChip));
      expect(filters, hasLength(4));
      expect(filters.every((chip) => chip.avatar is Icon), isTrue);

      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();

      expect(markAllRequestCount, 1);
      expect(find.text('Mark all as read'), findsNothing);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });
}
