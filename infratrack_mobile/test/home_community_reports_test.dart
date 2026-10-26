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
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
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
        if (request.url.path.endsWith('/mobile/issues/1/discussion')) {
          return http.Response(
            jsonEncode({
              'comments': [
                {
                  'id': 1,
                  'body': 'The city team is inspecting this issue.',
                  'author_name': 'InfraTrack Staff',
                  'author_role': 'staff',
                  'created_at': '2026-10-22T06:00:00.000Z',
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
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomePage())),
        );
        await tester.pumpAndSettle();

        final reportCards = tester
            .widgetList<ReportCard>(find.byType(ReportCard))
            .toList();

        expect(requestedHomeUpdates, isTrue);
        expect(reportCards, hasLength(7));
        expect(find.text('Trako'), findsOneWidget);
        expect(
          find.textContaining('Need help with a report or city update?'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-trako-welcome')),
          findsOneWidget,
        );
        final mascot = tester.widget<Image>(
          find.byKey(const ValueKey('home-trako-mascot')),
        );
        expect(mascot.width, 132);
        expect(
          mascot.image,
          isA<AssetImage>().having(
            (image) => image.assetName,
            'assetName',
            'assets/chatbot_character/chatbot_face/mascot.png',
          ),
        );
        await tester.tap(find.byKey(const ValueKey('home-trako-welcome')));
        await tester.pumpAndSettle();
        expect(find.byType(ChatbotPage), findsOneWidget);
        expect(find.text('Trako'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

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
        final firstReportCard = find.byWidgetPredicate(
          (widget) =>
              widget is ReportCard && widget.title == 'Central approved 1',
        );
        final firstReportTitle = find.descendant(
          of: firstReportCard,
          matching: find.text('Central approved 1'),
        );
        await tester.tap(firstReportTitle);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('OFFICIAL FOLLOW-UP'));

        expect(find.text('Issue details'), findsOneWidget);
        expect(
          find.text('A neighborhood infrastructure report.'),
          findsOneWidget,
        );
        expect(
          find.text('The city team is inspecting this issue.'),
          findsOneWidget,
        );
        expect(find.text('Send reply'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        ApiService.httpClientFactory = originalClientFactory;
        await ApiService.signOutForExpiredSession();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
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
  'public_id': '$id',
  'title': title,
  'description': 'A neighborhood infrastructure report.',
  'category': 'Roads',
  'status': status,
  'location': location,
  'reporter_barangay': reporterBarangay,
  'created_at': '2026-10-21T06:00:00.000Z',
};
