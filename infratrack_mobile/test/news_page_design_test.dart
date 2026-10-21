import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infatrack/api_service.dart';
import 'package:infatrack/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('News page separates report updates from city advisories', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues')) {
        return http.Response(
          jsonEncode({
            'issues': [
              _issue(1, 'Road repair on Rizal Street', 'Roads', 'Reported'),
              _issue(2, 'Water supply restored', 'Water', 'Resolved'),
              _issue(3, 'Drainage clearing', 'Drainage', 'In progress'),
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/advisories')) {
        return http.Response(
          jsonEncode({
            'advisories': [
              _advisory(1, 'Flood warning', 'alert'),
              _advisory(2, 'Water service schedule', 'maint'),
              _advisory(3, 'Roadworks update', 'gen'),
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    try {
      await tester.pumpWidget(const MaterialApp(home: NewsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Report updates'), findsOneWidget);
      expect(find.text('City advisories'), findsOneWidget);
      expect(find.text('Road repair on Rizal Street'), findsOneWidget);
      expect(find.text('Flood warning'), findsOneWidget);
      expect(find.text('EMERGENCY ALERT'), findsOneWidget);
      expect(find.text('MAINTENANCE'), findsOneWidget);
      expect(find.text('CITY ANNOUNCEMENT'), findsOneWidget);
      expect(find.text('3'), findsNWidgets(2));
      expect(find.textContaining('Today'), findsWidgets);

      final horizontalLists = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      expect(horizontalLists, findsNWidgets(2));

      await tester.tap(find.text('Water').first);
      await tester.pumpAndSettle();

      expect(find.text('Water supply restored'), findsOneWidget);
      expect(find.text('Road repair on Rizal Street'), findsNothing);
      expect(find.text('Flood warning'), findsOneWidget);
      expect(find.text('Roadworks update'), findsOneWidget);

      await tester.ensureVisible(find.text('Emergency'));
      await tester.tap(find.text('Emergency'));
      await tester.pumpAndSettle();

      expect(find.text('Water supply restored'), findsOneWidget);
      expect(find.text('Flood warning'), findsOneWidget);
      expect(find.text('Water service schedule'), findsNothing);
      expect(find.text('Roadworks update'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      ApiService.httpClientFactory = originalClientFactory;
    }
  });

  testWidgets('News page shows helpful empty states for both feeds', (
    WidgetTester tester,
  ) async {
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues')) {
        return http.Response(jsonEncode({'issues': []}), 200);
      }
      if (request.url.path.endsWith('/mobile/advisories')) {
        return http.Response(jsonEncode({'advisories': []}), 200);
      }
      return http.Response('{}', 404);
    });

    try {
      await tester.pumpWidget(const MaterialApp(home: NewsPage()));
      await tester.pumpAndSettle();

      expect(find.text('No community reports yet'), findsOneWidget);
      expect(find.text('No current advisories'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      ApiService.httpClientFactory = originalClientFactory;
    }
  });

  testWidgets('News page offers retry when updates cannot be loaded', (
    WidgetTester tester,
  ) async {
    final originalClientFactory = ApiService.httpClientFactory;
    var advisoryRequests = 0;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues')) {
        return http.Response(jsonEncode({'issues': []}), 200);
      }
      if (request.url.path.endsWith('/mobile/advisories')) {
        advisoryRequests++;
        if (advisoryRequests == 1) {
          return http.Response(
            jsonEncode({'error': 'Temporarily unavailable'}),
            503,
          );
        }
        return http.Response(jsonEncode({'advisories': []}), 200);
      }
      return http.Response('{}', 404);
    });

    try {
      await tester.pumpWidget(const MaterialApp(home: NewsPage()));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load city updates from the server.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(advisoryRequests, 2);
      expect(find.text('City advisories'), findsOneWidget);
      expect(find.text('No current advisories'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      ApiService.httpClientFactory = originalClientFactory;
    }
  });
}

Map<String, dynamic> _issue(
  int id,
  String title,
  String category,
  String status,
) => {
  'id': id,
  'title': title,
  'category': category,
  'status': status,
  'location': 'Brgy. Central',
  'severity': 'Medium',
  'created_at': '2026-10-21T02:30:00.000Z',
};

Map<String, dynamic> _advisory(int id, String title, String type) => {
  'id': id,
  'title': title,
  'type': type,
  'message': 'A clear update for residents across Mati City.',
  'audience': 'All barangays',
  'created_at': '2026-10-21T02:30:00.000Z',
};
