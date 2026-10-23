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
          severity: 'Medium',
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

  testWidgets(
    'verification notice is centered without a card and keeps app navigation visible',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final originalClientFactory = ApiService.httpClientFactory;
      ApiService.httpClientFactory = () => MockClient((request) async {
        if (request.url.path.endsWith('/mobile/auth/login')) {
          return http.Response(
            jsonEncode({
              'token': 'report-verification-navigation-token',
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
                'standing': 'Active',
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/mobile/reports')) {
          return http.Response(jsonEncode({'reports': []}), 200);
        }
        if (request.url.path.endsWith('/mobile/issues')) {
          return http.Response(jsonEncode({'issues': []}), 200);
        }
        if (request.url.path.endsWith('/mobile/advisories')) {
          return http.Response(jsonEncode({'advisories': []}), 200);
        }
        if (request.url.path.endsWith('/mobile/notifications')) {
          return http.Response(jsonEncode({'notifications': []}), 200);
        }
        if (request.url.path.endsWith('/mobile/overview')) {
          return http.Response(
            jsonEncode({
              'summary': {
                'total': 0,
                'reported': 0,
                'inProgress': 0,
                'resolved': 0,
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      try {
        await ApiService.login('resident@example.test', 'test-password');
        await tester.pumpWidget(const MaterialApp(home: MainShell()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.text('Report'));
        await tester.pump();

        expect(find.text('Report an issue'), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Map'), findsOneWidget);
        expect(find.text('News'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
        expect(find.text('Your verification is in review'), findsOneWidget);
        expect(
          (tester.getCenter(find.text('Your verification is in review')).dx -
                  215)
              .abs(),
          lessThan(1),
        );
        final availableAreaCenter =
            (tester.getRect(find.byType(AppHeader)).bottom +
                tester.getTopLeft(find.byType(NavigationBar)).dy) /
            2;
        expect(
          (tester
                      .getCenter(
                        find.byKey(const ValueKey('verificationNoticeCenter')),
                      )
                      .dy -
                  availableAreaCenter)
              .abs(),
          lessThan(2),
        );
        expect(
          find.ancestor(
            of: find.text('Your verification is in review'),
            matching: find.byType(Card),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      } finally {
        ApiService.httpClientFactory = originalClientFactory;
        await ApiService.signOutForExpiredSession();
      }
    },
  );
}
