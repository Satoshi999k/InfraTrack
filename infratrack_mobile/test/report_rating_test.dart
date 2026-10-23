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

  testWidgets('resident can rate completed work and see the saved feedback', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    var ratingPosted = false;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'rating-test-token',
            'user': {'id': 42, 'name': 'Test Resident', 'role': 'resident'},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/issues/MT-2026-240/rating') &&
          request.method == 'GET') {
        return http.Response(jsonEncode({'rating': null}), 200);
      }
      if (request.url.path.endsWith('/mobile/issues/MT-2026-240/rating') &&
          request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['rating'], 5);
        expect(body['comment'], 'The repair was completed quickly.');
        ratingPosted = true;
        return http.Response(
          jsonEncode({
            'rating': {
              'rating': 5,
              'comment': body['comment'],
              'created_at': '2026-10-23T08:00:00.000Z',
            },
          }),
          201,
        );
      }
      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(
        MaterialApp(
          home: MyReportDetailsPage(
            report: _report(
              reportId: 'MT-2026-240',
              title: 'Repaired streetlight',
              status: 'Resolved',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HOW DID WE DO?'), findsOneWidget);
      expect(find.text('Rate the completed work'), findsOneWidget);
      await tester.tap(find.byTooltip('5 stars'));
      await tester.enterText(
        find.byType(TextField),
        'The repair was completed quickly.',
      );
      await tester.tap(find.text('Submit rating'));
      await tester.pumpAndSettle();

      expect(ratingPosted, isTrue);
      expect(find.text('Thank you for helping Mati improve'), findsOneWidget);
      expect(find.text('Excellent'), findsOneWidget);
      expect(find.text('The repair was completed quickly.'), findsOneWidget);
      expect(find.text('Submit rating'), findsNothing);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('rating is offered only after report is resolved', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: MyReportDetailsPage(
          report: _report(
            reportId: 'MT-2026-241',
            title: 'Road repair underway',
            status: 'In progress',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HOW DID WE DO?'), findsNothing);
    expect(find.text('Submit rating'), findsNothing);
  });
}

_TestReport _report({
  required String reportId,
  required String title,
  required String status,
}) => (
  title: title,
  reportId: reportId,
  description: 'A reported infrastructure issue.',
  location: 'Central Mati',
  category: 'Roads',
  severity: 'Medium',
  assignedTeam: '',
  resolutionNote: '',
  progressPercentage: 30,
  progressUpdates: <Map<String, dynamic>>[],
  statusHistory: <Map<String, dynamic>>[],
  coordinates: '',
  age: '2026-10-20T10:00:00.000Z',
  image: '',
  status: status,
  color: teal,
  icon: Icons.add_road_rounded,
);

typedef _TestReport = ({
  String title,
  String reportId,
  String description,
  String location,
  String category,
  String severity,
  String assignedTeam,
  String resolutionNote,
  int progressPercentage,
  List<Map<String, dynamic>> progressUpdates,
  List<Map<String, dynamic>> statusHistory,
  String coordinates,
  String age,
  String image,
  String status,
  Color color,
  IconData icon,
});
