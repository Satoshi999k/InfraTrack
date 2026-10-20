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

  testWidgets('News feed uses a shimmer while advisories load', (
    WidgetTester tester,
  ) async {
    await _expectFeedSkeleton(tester, const NewsPage(), '/mobile/advisories', {
      'advisories': [],
    });
  });

  testWidgets('My Reports uses a shimmer while reports load', (
    WidgetTester tester,
  ) async {
    await _expectFeedSkeleton(
      tester,
      const MyReportsPage(),
      '/mobile/reports',
      {'reports': []},
    );
  });

  testWidgets('Notifications uses a shimmer while notifications load', (
    WidgetTester tester,
  ) async {
    await _expectFeedSkeleton(
      tester,
      const NotificationsPage(),
      '/mobile/notifications',
      {'notifications': []},
    );
  });
}

Future<void> _expectFeedSkeleton(
  WidgetTester tester,
  Widget page,
  String delayedPath,
  Map<String, dynamic> delayedPayload,
) async {
  SharedPreferences.setMockInitialValues({});
  final originalClientFactory = ApiService.httpClientFactory;
  final delayedResponse = Completer<http.Response>();
  ApiService.httpClientFactory = () => MockClient((request) async {
    if (request.url.path.endsWith('/mobile/auth/login')) {
      return http.Response(
        jsonEncode({
          'token': 'feed-loading-test-token',
          'user': {'id': 42, 'name': 'Test Resident'},
        }),
        200,
      );
    }
    if (request.url.path.endsWith(delayedPath)) {
      return delayedResponse.future;
    }
    if (request.url.path.endsWith('/mobile/issues')) {
      return http.Response(jsonEncode({'issues': []}), 200);
    }
    if (request.url.path.endsWith('/mobile/reports')) {
      return http.Response(jsonEncode({'reports': []}), 200);
    }
    if (request.url.path.endsWith('/mobile/advisories')) {
      return http.Response(jsonEncode({'advisories': []}), 200);
    }
    if (request.url.path.endsWith('/mobile/notifications')) {
      return http.Response(jsonEncode({'notifications': []}), 200);
    }
    return http.Response('Not found', 404);
  });

  try {
    await ApiService.login('resident@example.test', 'test-password');
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();

    expect(find.byType(SkeletonShimmer), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    delayedResponse.complete(http.Response(jsonEncode(delayedPayload), 200));
    await tester.pumpAndSettle();
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    ApiService.httpClientFactory = originalClientFactory;
    await ApiService.signOutForExpiredSession();
  }
}
