import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

const _notificationGroupKey = 'com.example.infatrack.updates';
const _notificationSummaryId = 0;

NotificationDetails groupedNotificationDetails({
  required bool groupSummary,
  int notificationCount = 1,
  String? latestTitle,
  String? latestBody,
  Uint8List? imageBytes,
}) => NotificationDetails(
  android: AndroidNotificationDetails(
    'infratrack_city_updates',
    'InfraTrack updates',
    channelDescription: 'Announcements and other InfraTrack notifications.',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_notification',
    groupKey: _notificationGroupKey,
    setAsGroupSummary: groupSummary,
    groupAlertBehavior: GroupAlertBehavior.children,
    onlyAlertOnce: true,
    playSound: !groupSummary,
    enableVibration: !groupSummary,
    styleInformation: groupSummary
        ? InboxStyleInformation(
            [latestTitle, latestBody].whereType<String>().toList(),
            contentTitle: 'InfraTrack updates',
            summaryText:
                '$notificationCount ${notificationCount == 1 ? 'update' : 'updates'} · Tap to view all notifications.',
          )
        : imageBytes == null
        ? null
        : BigPictureStyleInformation(
            ByteArrayAndroidBitmap(imageBytes),
            contentTitle: latestTitle,
            summaryText: latestBody,
            showBigPictureWhenCollapsed: true,
          ),
  ),
);

Future<Uint8List?> _downloadNotificationImage(String? imageUrl) async {
  if (imageUrl == null || imageUrl.isEmpty) return null;
  final uri = Uri.tryParse(imageUrl);
  if (uri == null ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty) {
    return null;
  }

  final client = http.Client();
  try {
    final response = await client
        .send(http.Request('GET', uri)..headers['Accept'] = 'image/*')
        .timeout(const Duration(seconds: 6));
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final contentLength = int.tryParse(
      response.headers['content-length'] ?? '',
    );
    if (response.statusCode != 200 ||
        !contentType.startsWith('image/') ||
        (contentLength != null && contentLength > 4 * 1024 * 1024)) {
      return null;
    }

    final imageBytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 6),
    )) {
      if (imageBytes.length + chunk.length > 4 * 1024 * 1024) return null;
      imageBytes.add(chunk);
    }
    final bytes = imageBytes.takeBytes();
    return bytes.isEmpty ? null : bytes;
  } catch (error, stackTrace) {
    debugPrint('Could not download notification image: $error');
    debugPrintStack(stackTrace: stackTrace);
    return null;
  } finally {
    client.close();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.notification != null) return;

  try {
    await Firebase.initializeApp();
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
    await PushNotifications.createAndroidNotificationChannel(notifications);
    await PushNotifications.showGroupedNotification(notifications, message);
  } catch (error, stackTrace) {
    debugPrint('Could not display grouped background notification: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class PushNotifications {
  PushNotifications._();

  static final instance = PushNotifications._();
  static const _channelId = 'infratrack_city_updates';
  static const _channelName = 'InfraTrack updates';
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initializing;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  void Function(Map<String, dynamic> data)? onNotificationTap;
  Map<String, dynamic>? _pendingNotificationTap;
  bool _initialized = false;
  String? _currentToken;

  static Future<void> createAndroidNotificationChannel(
    FlutterLocalNotificationsPlugin notifications,
  ) async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Announcements and other InfraTrack notifications.',
      importance: Importance.high,
    );
    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showGroupedNotification(
    FlutterLocalNotificationsPlugin notifications,
    RemoteMessage message,
  ) async {
    final title = message.notification?.title ?? message.data['title'];
    final body =
        message.notification?.body ??
        message.data['message'] ??
        message.data['body'];
    if (title == null || title.isEmpty || body == null || body.isEmpty) return;

    final payload = jsonEncode(message.data);
    final parsedId = int.tryParse(
      message.data['notificationId']?.toString() ?? '',
    );
    final childId = parsedId != null && parsedId > 0
        ? parsedId
        : (message.messageId?.hashCode.abs() ?? 1).clamp(1, 0x7ffffffe).toInt();
    await notifications.show(
      id: childId,
      title: title,
      body: body,
      notificationDetails: groupedNotificationDetails(
        groupSummary: false,
        latestTitle: title,
        latestBody: body,
      ),
      payload: payload,
    );
    final activeNotifications = await notifications.getActiveNotifications();
    final activeNotificationCount = activeNotifications
        .where(
          (activeNotification) =>
              activeNotification.groupKey == _notificationGroupKey &&
              activeNotification.id != _notificationSummaryId,
        )
        .length;
    final notificationCount = activeNotificationCount == 0
        ? 1
        : activeNotificationCount;
    await notifications.show(
      id: _notificationSummaryId,
      title:
          'InfraTrack · $notificationCount ${notificationCount == 1 ? 'update' : 'updates'}',
      body: title,
      notificationDetails: groupedNotificationDetails(
        groupSummary: true,
        notificationCount: notificationCount,
        latestTitle: title,
        latestBody: body,
      ),
      payload: jsonEncode({'openNotifications': 'true'}),
    );

    if (message.data['advisoryId'] == null) return;
    final imageBytes = await _downloadNotificationImage(
      message.data['imageUrl']?.toString(),
    );
    if (imageBytes == null) return;

    await notifications.show(
      id: childId,
      title: title,
      body: body,
      notificationDetails: groupedNotificationDetails(
        groupSummary: false,
        latestTitle: title,
        latestBody: body,
        imageBytes: imageBytes,
      ),
      payload: payload,
    );
  }

  Future<void> initialize({required bool authenticated}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await (_initializing ??= _initialize());
      if (authenticated) await _registerCurrentToken();
    } on FirebaseException catch (error, stackTrace) {
      _initializing = null;
      debugPrint('Firebase push initialization failed: $error\n$stackTrace');
    } on PlatformException catch (error, stackTrace) {
      _initializing = null;
      debugPrint(
        'Push notification platform setup failed: $error\n$stackTrace',
      );
    }

    final pendingTap = _pendingNotificationTap;
    if (_initialized && pendingTap != null && onNotificationTap != null) {
      _pendingNotificationTap = null;
      onNotificationTap!(pendingTap);
    }
  }

  Future<void> _initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final data = jsonDecode(payload);
        if (data is Map) _dispatchTap(Map<String, dynamic>.from(data));
      },
    );

    await createAndroidNotificationChannel(_localNotifications);

    await FirebaseMessaging.instance.requestPermission();
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Foreground push listener failed: $error\n$stackTrace');
      },
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _dispatchTap(message.data),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Push tap listener failed: $error\n$stackTrace');
      },
    );
    // The backend uses Firebase Admin's registration-token send API.
    // ignore: deprecated_member_use
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) {
        _currentToken = token;
        if (ApiService.isSignedIn) {
          unawaited(_registerToken(token));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh listener failed: $error\n$stackTrace');
      },
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _dispatchTap(initialMessage.data);
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      final data = jsonDecode(payload);
      if (data is Map) _dispatchTap(Map<String, dynamic>.from(data));
    }
    _initialized = true;
  }

  Future<void> _registerCurrentToken() async {
    // Firebase Admin sends to FCM registration tokens, not installation IDs.
    // ignore: deprecated_member_use
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    _currentToken = token;
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    try {
      await ApiService.registerPushToken(token);
    } catch (error, stackTrace) {
      debugPrint('Could not register InfraTrack push token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<String?> currentTokenForLogout() async {
    if (!_initialized) return null;
    try {
      // Keep logout tied to the same FCM token registered with the backend.
      // ignore: deprecated_member_use
      return _currentToken ??= await FirebaseMessaging.instance.getToken();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Could not read the current push token at logout: $error\n$stackTrace',
      );
      return null;
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Could not read the current push token at logout: $error\n$stackTrace',
      );
      return null;
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    await showGroupedNotification(_localNotifications, message);
  }

  void _dispatchTap(Map<String, dynamic> data) {
    final callback = onNotificationTap;
    if (callback == null) {
      _pendingNotificationTap = data;
      return;
    }
    callback(data);
  }

  Future<void> unregister() async {
    final token = await currentTokenForLogout();
    if (token == null) return;
    await ApiService.unregisterPushToken(token);
    _currentToken = null;
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    _foregroundSubscription = null;
    _openedSubscription = null;
    _tokenSubscription = null;
    _initialized = false;
  }
}
