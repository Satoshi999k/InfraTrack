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

  testWidgets('my reports shows a centered icon and message when empty', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'my-reports-empty-test-token',
            'user': {'id': 42, 'name': 'Test Resident'},
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/mobile/reports')) {
        return http.Response(jsonEncode({'reports': []}), 200);
      }

      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(const MaterialApp(home: MyReportsPage()));
      await tester.pumpAndSettle();

      final icon = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.assignment_outlined &&
            widget.size == 48,
      );
      final title = find.text('No reports yet');
      final message = find.text('You have not submitted any reports yet.');
      final screenCenter =
          tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;

      expect(icon, findsOneWidget);
      expect(title, findsOneWidget);
      expect(message, findsOneWidget);
      expect((tester.getCenter(icon).dx - screenCenter).abs(), lessThan(1));
      expect((tester.getCenter(title).dx - screenCenter).abs(), lessThan(1));
      expect((tester.getCenter(message).dx - screenCenter).abs(), lessThan(1));
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });
}
