import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infatrack/api_service.dart';
import 'package:infatrack/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('report card prioritizes location and opens GPS in details', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final fakeVideoPlatform = _FakeVideoPlayerPlatform();
    video_platform.VideoPlayerPlatform.instance = fakeVideoPlatform;
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'my-reports-test-token',
            'user': {'id': 42, 'name': 'Test Resident'},
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/mobile/reports')) {
        return http.Response(
          jsonEncode({
            'reports': [
              {
                'id': 7,
                'title': 'Damaged road near the public market',
                'description': 'The road surface is broken.',
                'category': 'Roads',
                'status': 'Reported',
                'location': 'Central Mati, near the public market',
                'latitude': 6.9542,
                'longitude': 126.2167,
                'media_url': 'https://example.test/report.mp4',
                'media_kind': 'video',
                'created_at': '2026-10-20T10:00:00.000Z',
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
      await tester.pumpWidget(const MaterialApp(home: MyReportsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Central Mati, near the public market'), findsOneWidget);
      expect(find.text('Report activity'), findsNothing);
      expect(find.textContaining('Lat 6.9542'), findsNothing);
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/icons/roads.png',
        ),
        findsWidgets,
      );

      await tester.ensureVisible(
        find.text('Damaged road near the public market'),
      );
      await tester.tap(find.text('Damaged road near the public market'));
      await tester.pumpAndSettle();

      expect(find.text('Issue details'), findsOneWidget);
      expect(find.text('VIDEO PREVIEW'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow));
      expect(fakeVideoPlatform.playCount, 1);
      expect(find.textContaining('GPS coordinates'), findsOneWidget);
      expect(find.textContaining('Lat 6.9542, Lon 126.2167'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });

  testWidgets('my reports summary and filters remain pinned while scrolling', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalClientFactory = ApiService.httpClientFactory;
    ApiService.httpClientFactory = () => MockClient((request) async {
      if (request.url.path.endsWith('/mobile/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'my-reports-test-token',
            'user': {'id': 42, 'name': 'Test Resident'},
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/mobile/reports')) {
        return http.Response(
          jsonEncode({
            'reports': List.generate(
              12,
              (index) => {
                'id': index + 1,
                'title': 'Test report ${index + 1}',
                'category': 'Roads',
                'status': 'Reported',
                'created_at': '2026-10-20T10:00:00.000Z',
              },
            ),
          }),
          200,
        );
      }

      return http.Response('Not found', 404);
    });

    try {
      await ApiService.login('resident@example.test', 'test-password');
      await tester.pumpWidget(const MaterialApp(home: MyReportsPage()));
      await tester.pumpAndSettle();

      final headerLabel = find.text('ACTIVITY CENTER');
      final initialHeaderTop = tester.getTopLeft(headerLabel).dy;
      expect(find.text('Test report 1'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(headerLabel).dy, initialHeaderTop);
      expect(find.text('FILTER BY STATUS'), findsOneWidget);
      expect(find.text('RECENT REPORTS'), findsOneWidget);
    } finally {
      ApiService.httpClientFactory = originalClientFactory;
      await ApiService.signOutForExpiredSession();
    }
  });
}

class _FakeVideoPlayerPlatform extends video_platform.VideoPlayerPlatform {
  int _nextPlayerId = 0;
  final Map<int, StreamController<video_platform.VideoEvent>> _events = {};
  int playCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(
    video_platform.VideoCreationOptions options,
  ) async {
    final playerId = _nextPlayerId++;
    final events = StreamController<video_platform.VideoEvent>();
    events.add(
      video_platform.VideoEvent(
        eventType: video_platform.VideoEventType.initialized,
        duration: const Duration(seconds: 3),
        size: const Size(640, 480),
      ),
    );
    _events[playerId] = events;
    return playerId;
  }

  @override
  Stream<video_platform.VideoEvent> videoEventsFor(int playerId) =>
      _events[playerId]!.stream;

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool enabled,
  ) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async {
    playCount++;
    _events[playerId]!.add(
      video_platform.VideoEvent(
        eventType: video_platform.VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    _events[playerId]!.add(
      video_platform.VideoEvent(
        eventType: video_platform.VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Widget buildViewWithOptions(video_platform.VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}
