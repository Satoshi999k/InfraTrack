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

  testWidgets('my reports summary and filters remain pinned while scrolling', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'my-reports-test-token',
            'user': {'id': 42, 'name': 'Test Resident'},
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/mobile/reports')) {
        return http.Response(
          jsonEncode({
            'reports': List.generate(
              12,
              (index) => {
                'id': index + 1,
                'title': 'Test report ${index + 1}',
                'category': 'Roads',
                'status': 'Reported',
                'created_at': '2026-10-20T10:00:00.000Z',
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
      await tester.pumpWidget(const MaterialApp(home: MyReportsPage()));
      await tester.pumpAndSettle();

      final headerLabel = find.text('ACTIVITY CENTER');
      final initialHeaderTop = tester.getTopLeft(headerLabel).dy;
      expect(find.text('Test report 1'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(headerLabel).dy, initialHeaderTop);
      expect(find.text('FILTER BY STATUS'), findsOneWidget);
      expect(find.text('RECENT REPORTS'), findsOneWidget);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });
}
