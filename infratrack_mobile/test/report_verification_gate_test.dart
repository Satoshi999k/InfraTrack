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

  testWidgets('unverified resident cannot open the report form', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    final reportRequests = <http.Request>[];
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'report-verification-test-token',
            'user': {
              'id': 42,
              'name': 'Test Resident',
              'verification': 'Pending ID match',
            },
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
              'verification': 'Pending ID match',
            },
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/mobile/reports')) {
        reportRequests.add(request);
      }

      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(const MaterialApp(home: ReportPage()));
      await tester.pumpAndSettle();

      expect(find.text('REPORTING ACCESS'), findsOneWidget);
      expect(find.text('PENDING REVIEW'), findsOneWidget);
      expect(find.text('Your verification is in review'), findsOneWidget);
      expect(find.text('Submit report'), findsNothing);
      expect(find.byType(TextField), findsNothing);

      await expectLater(
        ApiService.createReport(
          title: 'Road issue',
          description: 'A damaged road.',
          category: 'Roads',
          location: 'Mati City',
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'ACCOUNT_NOT_VERIFIED',
          ),
        ),
      );
      expect(reportRequests, isEmpty);

      await tester.tap(find.text('View verification status'));
      await tester.pumpAndSettle();
      expect(find.text('Identity verification'), findsOneWidget);
      expect(find.text('PENDING REVIEW'), findsOneWidget);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });
}
