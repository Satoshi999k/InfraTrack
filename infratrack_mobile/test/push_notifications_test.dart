import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/push_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('individual notifications share one Android notification group', () {
    final details = groupedNotificationDetails(groupSummary: false).android!;

    expect(infraTrackNotificationChannelId, 'infratrack_city_updates_v3');
    expect(details.groupKey, isNotEmpty);
    expect(details.setAsGroupSummary, isFalse);
    expect(details.groupAlertBehavior, GroupAlertBehavior.children);
    expect(details.onlyAlertOnce, isTrue);
    expect(details.channelId, infraTrackNotificationChannelId);
    expect(details.icon, 'infratrack_notification');
    expect(details.largeIcon?.data, 'infratrack_launcher');
    expect(details.importance, Importance.high);
    expect(details.priority, Priority.high);
    expect(details.playSound, isTrue);
    expect(details.enableVibration, isTrue);
  });

  test('push image preview is shown even without an advisory ID', () async {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final shownNotifications = <Map<Object?, Object?>>[];
    final originalPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'show') {
            shownNotifications.add(
              Map<Object?, Object?>.from(call.arguments as Map),
            );
          }
          if (call.method == 'getActiveNotifications') {
            return <Map<Object?, Object?>>[];
          }
          return null;
        });

    try {
      await PushNotifications.showGroupedNotification(
        FlutterLocalNotificationsPlugin(),
        RemoteMessage(
          data: {
            'title': 'Road maintenance',
            'message': 'Repairs begin today.',
            'imageUrl': 'https://example.test/road.jpg',
          },
        ),
        imageDownloader: (imageUrl) async {
          expect(imageUrl, 'https://example.test/road.jpg');
          return Uint8List.fromList([1, 2, 3]);
        },
      );

      final reportNotification = shownNotifications.last;
      final platformDetails =
          reportNotification['platformSpecifics']! as Map<Object?, Object?>;
      expect(
        platformDetails['style'],
        AndroidNotificationStyle.bigPicture.index,
      );
    } finally {
      debugDefaultTargetPlatformOverride = originalPlatform;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test('group summary is silent and displays an inbox-style digest', () {
    final details = groupedNotificationDetails(groupSummary: true).android!;

    expect(details.groupKey, isNotEmpty);
    expect(details.channelId, infraTrackNotificationChannelId);
    expect(details.setAsGroupSummary, isTrue);
    expect(details.groupAlertBehavior, GroupAlertBehavior.children);
    expect(details.playSound, isFalse);
    expect(details.enableVibration, isFalse);
    expect(details.styleInformation, isA<InboxStyleInformation>());
  });

  test(
    'advisory notification uses its image as a collapsed and expanded preview',
    () {
      final details = groupedNotificationDetails(
        groupSummary: false,
        latestTitle: 'Road closure update',
        latestBody: 'Details for tonight.',
        imageBytes: Uint8List.fromList([1, 2, 3]),
      ).android!;

      final style = details.styleInformation! as BigPictureStyleInformation;
      expect(style.bigPicture, isA<ByteArrayAndroidBitmap>());
      expect(style.showBigPictureWhenCollapsed, isTrue);
      expect(style.contentTitle, 'Road closure update');
      expect(style.summaryText, 'Details for tonight.');
    },
  );
}
