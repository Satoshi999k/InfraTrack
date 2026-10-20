import 'dart:async';
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

  testWidgets('Home shows a shaped shimmer while dashboard data loads', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    final issuesResponse = Completer<http.Response>();
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'home-loading-test-token',
            'user': {'id': 42, 'name': 'Test Resident'},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/issues')) {
        return issuesResponse.future;
      }
      if (request.url.path.endsWith('/mobile/reports')) {
        return http.Response(jsonEncode({'reports': []}), 200);
      }
      if (request.url.path.endsWith('/mobile/overview')) {
        return http.Response(jsonEncode({'overview': {}}), 200);
      }
      if (request.url.path.endsWith('/mobile/notifications')) {
        return http.Response(jsonEncode({'notifications': []}), 200);
      }
      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pump();

      expect(find.byType(SkeletonShimmer), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SkeletonBlock), findsWidgets);

      issuesResponse.complete(http.Response(jsonEncode({'issues': []}), 200));
      await tester.pumpAndSettle();

      expect(find.text('Spot an infrastructure issue?'), findsOneWidget);
      expect(find.text('Reports near you'), findsOneWidget);
      expect(find.text('Your community, in focus'), findsOneWidget);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });
}
