import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/push_notifications.dart';

void main() {
  test('individual notifications share one Android notification group', () {
    final details = groupedNotificationDetails(groupSummary: false).android!;

    expect(details.groupKey, isNotEmpty);
    expect(details.setAsGroupSummary, isFalse);
    expect(details.groupAlertBehavior, GroupAlertBehavior.children);
    expect(details.onlyAlertOnce, isTrue);
    expect(details.channelId, infraTrackNotificationChannelId);
    expect(details.importance, Importance.high);
    expect(details.priority, Priority.high);
    expect(details.playSound, isTrue);
    expect(details.enableVibration, isTrue);
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
