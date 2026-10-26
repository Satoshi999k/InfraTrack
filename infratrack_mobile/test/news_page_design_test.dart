import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infatrack/api_service.dart';
import 'package:infatrack/appearance_preferences.dart';
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
              _issue(
                1,
                'Road repair on Rizal Street',
                'Roads',
                'Verified by inspector',
              ),
              _issue(2, 'Water supply restored', 'Water', 'Resolved'),
              _issue(3, 'Drainage clearing', 'Drainage', 'In progress'),
              _issue(4, 'Unverified road damage', 'Roads', 'Reported'),
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/advisories')) {
        return http.Response(
          jsonEncode({
            'advisories': [
              _advisory(1, 'Community equipment showcase', 'alert'),
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
      expect(find.text('Community equipment showcase'), findsOneWidget);
      expect(find.text('ADVERTISEMENT'), findsOneWidget);
      expect(find.text('Emergency'), findsNothing);
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

      final drainageFilter = find.text('Drainage').first;
      await tester.ensureVisible(drainageFilter);
      await tester.tap(drainageFilter);
      await tester.pumpAndSettle();

      expect(find.text('Drainage clearing'), findsOneWidget);
      expect(find.text('Road repair on Rizal Street'), findsNothing);
      expect(find.text('Community equipment showcase'), findsOneWidget);
      expect(find.text('Roadworks update'), findsOneWidget);

      await tester.ensureVisible(find.text('Advertisement'));
      await tester.tap(find.text('Advertisement'));
      await tester.pumpAndSettle();

      expect(find.text('Drainage clearing'), findsOneWidget);
      expect(find.text('Community equipment showcase'), findsOneWidget);
      expect(find.text('Water service schedule'), findsNothing);
      expect(find.text('Roadworks update'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      ApiService.httpClientFactory = originalClientFactory;
    }
  });

  testWidgets(
    'News report and announcement cards remain readable in dark mode',
    (WidgetTester tester) async {
      final originalClientFactory = ApiService.httpClientFactory;
      ApiService.httpClientFactory = () => MockClient((request) async {
        if (request.url.path.endsWith('/mobile/issues')) {
          return http.Response(
            jsonEncode({
              'issues': [
                _issue(1, 'Dark mode road update', 'Roads', 'In progress'),
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/mobile/advisories')) {
          return http.Response(
            jsonEncode({
              'advisories': [_advisory(2, 'Dark mode city notice', 'gen')],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/mobile/reports')) {
          return http.Response(jsonEncode({'reports': []}), 200);
        }
        return http.Response('{}', 404);
      });
      final darkTheme = buildInfraTheme(
        const InfraAppearance(theme: 'dark'),
        Brightness.dark,
      );

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: darkTheme,
            darkTheme: darkTheme,
            themeMode: ThemeMode.dark,
            home: const NewsPage(),
          ),
        );
        await tester.pumpAndSettle();

        final reportTitle = tester.widget<Text>(
          find.text('Dark mode road update'),
        );
        expect(reportTitle.style?.color, darkTheme.colorScheme.onSurface);
        final reportMaterial = tester.widget<Material>(
          find
              .ancestor(
                of: find.text('Dark mode road update'),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(reportMaterial.color, darkTheme.colorScheme.surface);

        await tester.ensureVisible(find.text('CITY ANNOUNCEMENT'));
        expect(
          tester.widget<Text>(find.text('CITY ANNOUNCEMENT')).style?.color,
          const Color(0xFF75D5CF),
        );
        expect(
          tester.widget<Text>(find.text('Dark mode city notice')).style?.color,
          darkTheme.colorScheme.onSurface,
        );
        final advisoryMaterial = tester.widget<Material>(
          find
              .ancestor(
                of: find.text('Dark mode city notice'),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(advisoryMaterial.color, darkTheme.colorScheme.surface);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        ApiService.httpClientFactory = originalClientFactory;
      }
    },
  );

  testWidgets('city advisory opens full details with its comment thread', (
    WidgetTester tester,
  ) async {
    final originalClientFactory = ApiService.httpClientFactory;
    var socialRequestCount = 0;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues')) {
        return http.Response(jsonEncode({'issues': []}), 200);
      }
      if (request.url.path.endsWith('/mobile/advisories')) {
        return http.Response(
          jsonEncode({
            'advisories': [
              {
                ..._advisory(31, 'Full city advisory', 'gen'),
                'message': 'First paragraph.\n\nAdditional important details.',
                'reaction_count': 4,
                'user_has_reacted': false,
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/advisories/31/social')) {
        socialRequestCount++;
        return http.Response(
          jsonEncode({
            'advisory': {
              ..._advisory(31, 'Full city advisory', 'gen'),
              'message': 'First paragraph.\n\nAdditional important details.',
            },
            'reaction_count': 4,
            'user_has_reacted': false,
            'comments': [
              {
                'id': 1,
                'author_name': 'Mati Resident',
                'body': 'Thank you for sharing this update.',
                'created_at': '2026-10-21T02:30:00.000Z',
              },
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

      await tester.dragUntilVisible(
        find.text('Read more'),
        find.byType(ListView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();

      expect(socialRequestCount, 1);
      expect(
        find.textContaining('Additional important details.'),
        findsOneWidget,
      );
      expect(find.text('Mati Resident'), findsOneWidget);
      expect(find.text('Thank you for sharing this update.'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      ApiService.httpClientFactory = originalClientFactory;
    }
  });

  testWidgets('failed advisory media offers retry instead of loading forever', (
    WidgetTester tester,
  ) async {
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues')) {
        return http.Response(jsonEncode({'issues': []}), 200);
      }
      if (request.url.path.endsWith('/mobile/advisories')) {
        return http.Response(
          jsonEncode({
            'advisories': [
              {
                ..._advisory(7, 'Advisory with unavailable media', 'alert'),
                'media_url': 'https://example.test/missing-image.jpg',
                'media_kind': 'image',
              },
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

      expect(find.text('Media could not be loaded'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Advisory with unavailable media'), findsNWidgets(2));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      ApiService.httpClientFactory = originalClientFactory;
    }
  });

  testWidgets('News shows only approved reports and reveals older updates', (
    WidgetTester tester,
  ) async {
    final originalClientFactory = ApiService.httpClientFactory;
    var requestedVerifiedFeed = false;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues')) {
        requestedVerifiedFeed =
            request.url.queryParameters['verified_only'] == 'true';
        return http.Response(
          jsonEncode({
            'issues': [
              ...List.generate(
                12,
                (index) => _issue(
                  index + 1,
                  'Approved report ${index + 1}',
                  'Roads',
                  index.isEven ? 'Verified by inspector' : 'In progress',
                ),
              ),
              _issue(13, 'Unverified report', 'Roads', 'Reported'),
              _issue(14, 'Rejected report', 'Roads', 'Rejected'),
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/advisories')) {
        return http.Response(jsonEncode({'advisories': []}), 200);
      }
      return http.Response('{}', 404);
    });

    try {
      await tester.pumpWidget(const MaterialApp(home: NewsPage()));
      await tester.pumpAndSettle();

      expect(requestedVerifiedFeed, isTrue);
      expect(find.text('Approved report 1'), findsOneWidget);
      expect(find.text('Approved report 10'), findsOneWidget);
      expect(find.text('Approved report 11'), findsNothing);
      expect(find.text('Unverified report'), findsNothing);
      expect(find.text('Rejected report'), findsNothing);
      expect(find.text('See all previous reports (2)'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See all previous reports (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Approved report 11'), findsOneWidget);
      expect(find.text('Approved report 12'), findsOneWidget);
      expect(find.text('Unverified report'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      ApiService.httpClientFactory = originalClientFactory;
    }
  });

  testWidgets('News report updates open public details and follow-up', (
    WidgetTester tester,
  ) async {
    final originalClientFactory = ApiService.httpClientFactory;
    String? discussionAuthorization;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues')) {
        return http.Response(
          jsonEncode({
            'issues': [
              {
                ..._issue(
                  242,
                  'Central road repair update',
                  'Roads',
                  'In progress',
                ),
                'public_id': 'MT-2026-242',
                'description': 'A pothole near the central market.',
                'latitude': 6.96,
                'longitude': 126.2,
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/mobile/advisories')) {
        return http.Response(jsonEncode({'advisories': []}), 200);
      }
      if (request.url.path.endsWith('/mobile/issues/MT-2026-242/discussion') &&
          request.method == 'GET') {
        discussionAuthorization = request.headers['authorization'];
        return http.Response(
          jsonEncode({
            'comments': [
              {
                'id': 1,
                'body': 'The city crew is preparing the road repair.',
                'author_name': 'InfraTrack Staff',
                'author_role': 'staff',
                'created_at': '2026-10-22T06:00:00.000Z',
              },
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
      await tester.tap(find.text('Central road repair update'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('OFFICIAL FOLLOW-UP'));

      expect(find.text('Issue details'), findsOneWidget);
      expect(find.text('A pothole near the central market.'), findsOneWidget);
      expect(
        find.text('The city crew is preparing the road repair.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Only the reporter and authorized staff can reply. Everyone can read this follow-up.',
        ),
        findsOneWidget,
      );
      expect(find.text('Send reply'), findsNothing);
      expect(discussionAuthorization, isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
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

      expect(find.text('No verified report updates yet'), findsOneWidget);
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
  'public_id': 'MT-2026-$id',
  'title': title,
  'category': category,
  'description': 'An infrastructure issue reported by the community.',
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
