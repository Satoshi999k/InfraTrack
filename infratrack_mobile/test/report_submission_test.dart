import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infatrack/api_service.dart';
import 'package:infatrack/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final locationPlatform = _FakeGeolocatorPlatform();
  late GeolocatorPlatform originalLocationPlatform;
  late http.Client Function() originalClientFactory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    originalLocationPlatform = GeolocatorPlatform.instance;
    originalClientFactory = ApiService.httpClientFactory;
    GeolocatorPlatform.instance = locationPlatform;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'report-submission-test-token',
            'user': {
              'id': 42,
              'name': 'Test Resident',
              'verification': 'Verified',
              'standing': 'Active',
            },
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });
    await ApiService.login('resident@example.test', 'test-password');
  });

  tearDown(() async {
    GeolocatorPlatform.instance = originalLocationPlatform;
    ApiService.httpClientFactory = originalClientFactory;
    await ApiService.signOutForExpiredSession();
  });

  testWidgets(
    'shows truthful no-evidence progress and blocks duplicate submissions',
    (tester) async {
      final reportResponse = Completer<http.Response>();
      var reportRequestCount = 0;
      ApiService.httpClientFactory = () => MockClient((request) async {
        if (request.url.path.endsWith('/mobile/profile')) {
          return _verifiedProfileResponse();
        }
        if (request.url.path.endsWith('/mobile/reports')) {
          reportRequestCount++;
          return reportResponse.future;
        }
        return http.Response('Not found', 404);
      });

      await _openReportForm(tester);
      await tester.enterText(
        find.byType(TextField),
        'A large pothole by the market.',
      );
      await _scrollToSubmitButton(tester);
      await tester.tap(find.text('Submit report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Submitting your report'), findsOneWidget);
      expect(find.text('Upload evidence'), findsNothing);
      expect(find.text('Confirm location'), findsOneWidget);
      expect(find.text('Send report'), findsOneWidget);
      expect(reportRequestCount, 1);
      final submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submitting report…'),
      );
      expect(submitButton.onPressed, isNull);
      expect(reportRequestCount, 1);

      reportResponse.complete(
        http.Response(
          jsonEncode({
            'report': {'id': 101},
          }),
          201,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Report submitted'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('keeps the report draft when the server rejects submission', (
    tester,
  ) async {
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/profile')) {
        return _verifiedProfileResponse();
      }
      if (request.url.path.endsWith('/mobile/reports')) {
        return http.Response(
          jsonEncode({'error': 'Report service temporarily unavailable.'}),
          503,
        );
      }
      return http.Response('Not found', 404);
    });

    await _openReportForm(tester);
    const draft = 'Water is pooling beside the school entrance.';
    await tester.enterText(find.byType(TextField), draft);
    await _scrollToSubmitButton(tester);
    await tester.tap(find.text('Submit report'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Submitting your report'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      draft,
    );
    expect(find.text('Submit report'), findsOneWidget);
  });
}

Future<void> _openReportForm(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: ReportPage())),
  );
  await tester.pumpAndSettle();
  expect(find.text('Submit report'), findsOneWidget);
}

Future<void> _scrollToSubmitButton(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Submit report'));
  await tester.pumpAndSettle();
}

http.Response _verifiedProfileResponse() => http.Response(
  jsonEncode({
    'user': {
      'id': 42,
      'name': 'Test Resident',
      'verification': 'Verified',
      'standing': 'Active',
    },
  }),
  200,
);

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    longitude: 126.1986,
    latitude: 6.9541,
    timestamp: DateTime(2025),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
