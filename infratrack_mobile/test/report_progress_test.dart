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

  testWidgets('in-progress issue details show admin updates and progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'report-progress-test-token',
            'user': {'id': 42, 'name': 'Test Resident'},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/reports')) {
        return http.Response(
          jsonEncode({
            'reports': [
              {
                'id': 17,
                'title': 'Blocked drainage by the school',
                'description': 'Water collects after heavy rain.',
                'category': 'Drainage',
                'status': 'In progress',
                'progress_percentage': 65,
                'progress_updates': [
                  {
                    'note': 'The crew cleared the inlet and is replacing the damaged grate.',
                    'created_at': '2026-10-21T05:00:00.000Z',
                  },
                ],
                'status_history': [
                  {
                    'status': 'Reported',
                    'created_at': '2026-10-20T10:00:00.000Z',
                  },
                  {
                    'status': 'Verified by inspector',
                    'created_at': '2026-10-20T12:00:00.000Z',
                  },
                  {
                    'status': 'In progress',
                    'created_at': '2026-10-21T05:00:00.000Z',
                  },
                ],
                'location': 'Barangay Central',
                'created_at': '2026-10-20T10:00:00.000Z',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(const MaterialApp(home: MyReportsPage()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Blocked drainage by the school'));
      await tester.tap(find.text('Blocked drainage by the school'));
      await tester.pumpAndSettle();

      expect(find.text('CITY TEAM PROGRESS'), findsOneWidget);
      expect(find.text('Work is underway'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.text('Reported'), findsOneWidget);
      expect(find.text('Inspected'), findsOneWidget);
      expect(find.text('In progress'), findsWidgets);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Updates from city team'), findsOneWidget);
      expect(
        find.text(
          'The crew cleared the inlet and is replacing the damaged grate.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });

  testWidgets('rejected reports do not show an in-progress timeline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'report-progress-test-token',
            'user': {'id': 42, 'name': 'Test Resident'},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/reports')) {
        return http.Response(
          jsonEncode({
            'reports': [
              {
                'id': 18,
                'title': 'Rejected issue',
                'description': 'A submitted issue.',
                'category': 'Roads',
                'status': 'Rejected',
                'progress_percentage': 0,
                'progress_updates': [],
                'status_history': [
                  {
                    'status': 'Reported',
                    'created_at': '2026-10-20T10:00:00.000Z',
                  },
                  {
                    'status': 'Rejected',
                    'created_at': '2026-10-21T05:00:00.000Z',
                  },
                ],
                'location': 'Barangay Central',
                'created_at': '2026-10-20T10:00:00.000Z',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(const MaterialApp(home: MyReportsPage()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Rejected issue'));
      await tester.tap(find.text('Rejected issue'));
      await tester.pumpAndSettle();

      expect(find.text('CITY TEAM PROGRESS'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });
}
