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
    'Home shows every approved or in-progress report in the resident barangay',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final originalClientFactory = ApiService.httpClientFactory;
      var requestedHomeUpdates = false;
      ApiService.httpClientFactory = () => MockClient((request) async {
        if (request.url.path.endsWith('/mobile/auth/login')) {
          return http.Response(
            jsonEncode({
              'token': 'home-community-reports-test-token',
              'user': {
                'id': 42,
                'name': 'Test Resident',
                'barangay': 'Barangay Central',
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/mobile/issues')) {
          requestedHomeUpdates =
              request.url.queryParameters['home_updates_only'] == 'true';
          return http.Response(
            jsonEncode({
              'issues': [
                for (var index = 1; index <= 7; index++)
                  _issue(
                    index,
                    'Central approved $index',
                    index.isEven ? 'In progress' : 'Verified by inspector',
                    index.isEven ? 'Mati City' : 'Barangay Central',
                    reporterBarangay: 'Barangay Central',
                  ),
                _issue(
                  8,
                  'Central awaiting review',
                  'Reported',
                  'Brgy. Central',
                ),
                _issue(9, 'Central resolved', 'Resolved', 'Brgy. Central'),
                _issue(
                  10,
                  'Dawan active report',
                  'In progress',
                  'Barangay Dawan',
                ),
              ],
            }),
            200,
          );
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
        await tester.pumpAndSettle();

        final reportCards = tester
            .widgetList<ReportCard>(find.byType(ReportCard))
            .toList();

        expect(requestedHomeUpdates, isTrue);
        expect(reportCards, hasLength(7));
        expect(
          reportCards.map((card) => card.title),
          contains('Central approved 1'),
        );
        expect(
          reportCards.map((card) => card.title),
          contains('Central approved 7'),
        );
        expect(
          reportCards.map((card) => card.title),
          isNot(contains('Central awaiting review')),
        );
        expect(
          reportCards.map((card) => card.title),
          isNot(contains('Central resolved')),
        );
        expect(
          reportCards.map((card) => card.title),
          isNot(contains('Dawan active report')),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        ApiService.httpClientFactory = originalClientFactory;
        await ApiService.signOutForExpiredSession();
      }
    },
  );
}

Map<String, dynamic> _issue(
  int id,
  String title,
  String status,
  String location, {
  String? reporterBarangay,
}) => {
  'id': id,
  'title': title,
  'description': 'A neighborhood infrastructure report.',
  'category': 'Roads',
  'status': status,
  'location': location,
  'reporter_barangay': reporterBarangay,
  'created_at': '2026-10-21T06:00:00.000Z',
};
