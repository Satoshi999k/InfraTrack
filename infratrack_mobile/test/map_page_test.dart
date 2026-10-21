import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infatrack/api_service.dart';
import 'package:infatrack/main.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('map starts centered on a Central resident barangay', (
    tester,
  ) async {
    ApiService.currentUser = {'barangay': 'Barangay Central'};
    addTearDown(() => ApiService.currentUser = null);

    await tester.pumpWidget(const MaterialApp(home: MapPage()));

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter, const LatLng(6.9612515, 126.2069944));
  });

  testWidgets('map starts centered on a Dawan resident barangay', (
    tester,
  ) async {
    ApiService.currentUser = {'barangay': 'Dawan'};
    addTearDown(() => ApiService.currentUser = null);

    await tester.pumpWidget(const MaterialApp(home: MapPage()));

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter, const LatLng(6.8993278, 126.1510600));
  });

  testWidgets('map category filters update the matching report count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues')) {
        return http.Response(
          jsonEncode({
            'issues': [
              _issue(
                id: 1,
                title: 'Road damage',
                category: 'Roads',
                latitude: 6.953,
                longitude: 126.228,
              ),
              _issue(
                id: 2,
                title: 'Damaged barangay hall',
                category: 'Public Buildings',
              ),
            ],
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    try {
      await tester.pumpWidget(const MaterialApp(home: MapPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2 matching reports'), findsOneWidget);
      expect(find.byIcon(Icons.add_road_rounded), findsWidgets);
      expect(find.byIcon(Icons.apartment_rounded), findsWidgets);

      final publicBuildingsFilter = find.text('Public Buildings').first;
      final categoryScroller = find
          .ancestor(
            of: publicBuildingsFilter,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(categoryScroller, const Offset(-220, 0));
      await tester.pumpAndSettle();
      await tester.tap(publicBuildingsFilter);
      await tester.pumpAndSettle();

      expect(find.text('1 matching report'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
    }
  });

  testWidgets('map report pins use distinct colors for each category', (
    tester,
  ) async {
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues')) {
        return http.Response(
          jsonEncode({
            'issues': [
              _issue(
                id: 1,
                title: 'Road damage',
                category: 'Roads',
                latitude: 6.953,
                longitude: 126.228,
              ),
              _issue(
                id: 2,
                title: 'Damaged barangay hall',
                category: 'Public Buildings',
                latitude: 6.953,
                longitude: 126.228,
              ),
              _issue(
                id: 3,
                title: 'Blocked drainage',
                category: 'Drainage',
                latitude: 6.953,
                longitude: 126.228,
              ),
              _issue(
                id: 4,
                title: 'Streetlight outage',
                category: 'Streetlights',
                latitude: 6.953,
                longitude: 126.228,
              ),
              _issue(
                id: 5,
                title: 'Leaning electric pole',
                category: 'Electric Poles',
                latitude: 6.953,
                longitude: 126.228,
              ),
            ],
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    try {
      await tester.pumpWidget(const MaterialApp(home: MapPage()));
      await tester.pumpAndSettle();

      expect(find.text('5 matching reports'), findsOneWidget);
      final reportMarkers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .where(
            (marker) =>
                marker.key?.toString().contains('report-marker-') ?? false,
          )
          .toList();
      expect(reportMarkers, hasLength(5));
      expect(
        reportMarkers
            .map(
              (marker) => '${marker.point.latitude},${marker.point.longitude}',
            )
            .toSet(),
        hasLength(5),
      );

      expect(tester.takeException(), isNull);

      final roadMarker = find.ancestor(
        of: find.byIcon(Icons.add_road_rounded),
        matching: find.byType(AnimatedScale),
      );
      await tester.tap(roadMarker);
      await tester.pumpAndSettle();
      expect(find.text('Road damage'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      final buildingsMarker = find.ancestor(
        of: find.byIcon(Icons.apartment_rounded),
        matching: find.byType(AnimatedScale),
      );
      await tester.tap(buildingsMarker);
      await tester.pumpAndSettle();
      expect(find.text('Damaged barangay hall'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
    }
  });

  testWidgets('map report loading error offers retry', (tester) async {
    final originalClientFactory = ApiService.httpClientFactory;
    var issueRequests = 0;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/issues')) {
        issueRequests++;
        if (issueRequests == 1) {
          return http.Response(
            jsonEncode({'error': 'Reports could not be loaded.'}),
            503,
          );
        }
        return http.Response(
          jsonEncode({
            'issues': [_issue(id: 1, title: 'Road damage', category: 'Roads')],
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    try {
      await tester.pumpWidget(const MaterialApp(home: MapPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Reports unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(issueRequests, 2);
      expect(find.text('1 matching report'), findsOneWidget);
      expect(find.text('Reports unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
    }
  });
}

Map<String, dynamic> _issue({
  required int id,
  required String title,
  required String category,
  double latitude = 6.9612515,
  double longitude = 126.2069944,
}) => {
  'id': id,
  'title': title,
  'description': 'A community-reported infrastructure issue.',
  'category': category,
  'location': 'Barangay Central',
  'status': 'Reported',
  'severity': 'Medium',
  'latitude': latitude,
  'longitude': longitude,
  'created_at': '2026-10-20T10:00:00.000Z',
};
