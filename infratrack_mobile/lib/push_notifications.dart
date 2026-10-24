import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

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

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Announcements and other InfraTrack notifications.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

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
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['message'];
    if (title == null || title.isEmpty || body == null || body.isEmpty) return;

    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
      ),
      payload: jsonEncode(message.data),
    );
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
