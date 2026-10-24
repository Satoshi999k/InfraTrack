import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infatrack/api_service.dart';
import 'package:infatrack/appearance_preferences.dart';
import 'package:infatrack/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('public report follow-up can be read without signing in', () async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    String? authorization;
    ApiService.httpClientFactory = () => MockClient((request) async {
      authorization = request.headers['authorization'];
      return http.Response(
        jsonEncode({
          'comments': [_comment(1, 'A public progress update.')],
        }),
        200,
      );
    });

    try {
      await ApiService.signOutForExpiredSession();
      final comments = await ApiService.reportDiscussion('MT-2026-241');

      expect(comments.single['body'], 'A public progress update.');
      expect(authorization, isNull);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
    }
  });

  testWidgets('report owner can read, expand, and reply to follow-up', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    final comments = [
      _comment(1, 'Earlier reply'),
      _comment(2, 'Middle reply'),
      _comment(3, 'Latest reply'),
    ];
    var postedReply = false;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'discussion-test-token',
            'user': {'id': 42, 'name': 'Test Resident', 'role': 'resident'},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/issues/MT-2026-238/discussion') &&
          request.method == 'GET') {
        return http.Response(jsonEncode({'comments': comments}), 200);
      }
      if (request.url.path.endsWith('/mobile/issues/MT-2026-238/discussion') &&
          request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['body'], 'Thanks for the update.');
        postedReply = true;
        final reply = _comment(4, body['body'] as String);
        comments.add(reply);
        return http.Response(jsonEncode({'comment': reply}), 201);
      }
      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInfraTheme(
            const InfraAppearance(accent: 'rose'),
            Brightness.light,
          ),
          home: MyReportDetailsPage(
            report: _report(
              reportId: 'MT-2026-238',
              title: 'Broken road near the market',
              status: 'In progress',
            ),
            canReply: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('OFFICIAL FOLLOW-UP'));

      expect(find.text('OFFICIAL FOLLOW-UP'), findsOneWidget);
      expect(find.text('Earlier reply'), findsNothing);
      expect(find.text('Middle reply'), findsOneWidget);
      expect(find.text('Latest reply'), findsOneWidget);
      expect(find.text('View all 3 replies'), findsOneWidget);
      final sendReplyButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Send reply'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        sendReplyButton.style?.backgroundColor?.resolve({}),
        appearanceAccentColors['rose'],
      );

      await tester.tap(find.text('View all 3 replies'));
      await tester.pumpAndSettle();
      expect(find.text('Earlier reply'), findsOneWidget);
      expect(find.text('Show latest replies'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Thanks for the update.');
      await tester.tap(find.text('Send reply'));
      await tester.pumpAndSettle();

      expect(postedReply, isTrue);
      expect(find.text('Thanks for the update.'), findsOneWidget);
      expect(find.text('4 replies'), findsOneWidget);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('closed report follow-up remains readable but not replyable', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'closed-discussion-test-token',
            'user': {'id': 42, 'name': 'Test Resident', 'role': 'resident'},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/issues/MT-2026-239/discussion') &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'comments': [_comment(1, 'The city team completed the repair.')],
          }),
          200,
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
              reportId: 'MT-2026-239',
              title: 'Resolved drainage issue',
              status: 'Resolved',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('OFFICIAL FOLLOW-UP'));

      expect(find.text('The city team completed the repair.'), findsOneWidget);
      expect(
        find.text(
          'Replies are closed for resolved reports. You can still read the follow-up.',
        ),
        findsOneWidget,
      );
      expect(find.text('Send reply'), findsNothing);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });

  testWidgets('community viewers can read follow-up but cannot reply', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues/MT-2026-240/discussion') &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'comments': [_comment(1, 'The city crew inspected this issue.')],
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: MyReportDetailsPage(
            report: _report(
              reportId: 'MT-2026-240',
              title: 'Community road issue',
              status: 'In progress',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('OFFICIAL FOLLOW-UP'));

      expect(find.text('The city crew inspected this issue.'), findsOneWidget);
      expect(
        find.text(
          'Only the reporter and authorized staff can reply. Everyone can read this follow-up.',
        ),
        findsOneWidget,
      );
      expect(find.text('Send reply'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
    }
  });
}

Map<String, dynamic> _comment(int id, String body) => {
  'id': id,
  'body': body,
  'author_name': id == 1 ? 'InfraTrack Staff' : 'Resident',
  'author_role': id == 1 ? 'staff' : 'resident',
  'created_at': '2026-10-23T08:00:00.000Z',
};

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
