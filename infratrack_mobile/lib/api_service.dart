import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ReportSeverityAssessment {
  const ReportSeverityAssessment({
    required this.severity,
    required this.analysis,
  });

  final String severity;
  final String analysis;
}

const reportCommentMaxLength = 1000;
const reportRatingCommentMaxLength = 500;

const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _productionApiBaseUrl = 'https://infratrack-3a8u.onrender.com/api';

String get apiBaseUrl {
  if (_configuredApiBaseUrl.isNotEmpty) return _configuredApiBaseUrl;
  // Web preview uses the host machine's localhost.
  if (kIsWeb) return 'http://localhost:3001/api';
  return _productionApiBaseUrl;
}

String? publicMediaUrl(String? value) {
  if (value == null || value.isEmpty) return value;
  final mediaUri = Uri.tryParse(value);
  final apiUri = Uri.tryParse(apiBaseUrl);
  if (mediaUri == null || apiUri == null) return value;
  if (mediaUri.host != 'localhost' && mediaUri.host != '127.0.0.1') {
    return value;
  }
  return mediaUri.replace(host: apiUri.host, port: apiUri.port).toString();
}

class ApiService {
  static const _sessionTokenKey = 'session_token';
  static const _sessionUserKey = 'session_user';
  static const _lastOpenedKey = 'session_last_opened';
  // Keep the local restore window aligned with the server session lifetime.
  static const _sessionLifetime = Duration(hours: 8);

  static Map<String, dynamic>? currentUser;
  static String? _sessionToken;
  static final ValueNotifier<int> sessionExpired = ValueNotifier<int>(0);
  static final ValueNotifier<int> accountBanned = ValueNotifier<int>(0);
  static final ValueNotifier<int> notificationReadRevision = ValueNotifier<int>(
    0,
  );
  static int? lastReadNotificationId;
  static final ValueNotifier<String?> connectionIssue = ValueNotifier<String?>(
    null,
  );
  static final ValueNotifier<int> connectionRestored = ValueNotifier<int>(0);
  @visibleForTesting
  static http.Client Function() httpClientFactory = http.Client.new;
  static String? _sessionNotice;

  static bool get isSignedIn => _sessionToken != null;

  static bool get isCurrentUserVerified =>
      currentUser?['verification']?.toString().toLowerCase() == 'verified';

  static void _requireVerifiedAccount() {
    if (!isCurrentUserVerified) {
      throw const ApiException(
        'Your account must be verified before you can submit a report.',
        code: 'ACCOUNT_NOT_VERIFIED',
      );
    }
  }

  static void _markConnected() {
    if (connectionIssue.value == null) return;
    connectionIssue.value = null;
    connectionRestored.value++;
  }

  static Future<void> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_sessionTokenKey);
    final lastOpenedMilliseconds = preferences.getInt(_lastOpenedKey);
    if (token == null || lastOpenedMilliseconds == null) return;

    final lastOpened = DateTime.fromMillisecondsSinceEpoch(
      lastOpenedMilliseconds,
    );
    if (DateTime.now().difference(lastOpened) >= _sessionLifetime) {
      _sessionNotice = 'Your InfraTrack session expired after 8 hours of inactivity. Please sign in again.';
      await _clearStoredSession(preferences);
      return;
    }

    final storedUser = preferences.getString(_sessionUserKey);
    if (storedUser == null) {
      await _clearStoredSession(preferences);
      return;
    }
    final decodedUser = jsonDecode(storedUser);
    if (decodedUser is! Map) {
      await _clearStoredSession(preferences);
      return;
    }
    _sessionToken = token;
    currentUser = Map<String, dynamic>.from(decodedUser);
    await preferences.setInt(
      _lastOpenedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> _persistSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionTokenKey, _sessionToken!);
    await preferences.setString(_sessionUserKey, jsonEncode(currentUser));
    await preferences.setInt(
      _lastOpenedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> _clearStoredSession(SharedPreferences preferences) async {
    await preferences.remove(_sessionTokenKey);
    await preferences.remove(_sessionUserKey);
    await preferences.remove(_lastOpenedKey);
  }

  static Future<void> _recordSessionActivity(String? token) async {
    if (token == null || _sessionToken != token) return;
    final preferences = await SharedPreferences.getInstance();
    if (_sessionToken != token) return;
    await preferences.setInt(
      _lastOpenedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> _clearSession() async {
    _sessionToken = null;
    currentUser = null;
    final preferences = await SharedPreferences.getInstance();
    await _clearStoredSession(preferences);
  }

  static String? consumeSessionNotice() {
    final notice = _sessionNotice;
    _sessionNotice = null;
    return notice;
  }

  static Future<void> signOutForExpiredSession() async {
    await _clearSession();
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (authenticated && _sessionToken == null) {
      throw Exception('Please sign in to use this feature.');
    }

    final requestToken = authenticated ? _sessionToken : null;
    final client = httpClientFactory();
    try {
      final request = http.Request(method, Uri.parse('$apiBaseUrl$path'))
        ..headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      if (_sessionToken != null) {
        request.headers['Authorization'] = 'Bearer $_sessionToken';
      }
      final streamedResponse = await client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(timeout);
      _markConnected();
      if (response.statusCode != 401) {
        await _recordSessionActivity(requestToken);
      }
      return _decodeResponse(response, invalidateSession: authenticated);
    } on SocketException {
      connectionIssue.value = 'Could not connect to InfraTrack. Check your internet connection and try again.';
      throw Exception(
        'Unable to reach the backend server. Check your internet connection and API server status.',
      );
    } on http.ClientException {
      connectionIssue.value = 'Could not connect to InfraTrack. Check your internet connection and try again.';
      throw Exception(
        'Unable to reach the backend server. Check your internet connection and API server status.',
      );
    } on TimeoutException {
      connectionIssue.value = 'The server took too long to respond. Check your connection and try again.';
      throw Exception('The server took too long to respond. Please try again.');
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic> _decodeResponse(
    http.Response response, {
    bool invalidateSession = false,
  }) {
    if (response.statusCode == 401 && invalidateSession) {
      _sessionNotice = 'Your session has expired. For your security, please sign in again to continue.';
      unawaited(_clearSession());
      sessionExpired.value++;
    }
    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('The server returned an unexpected response.');
    }
    final body = Map<String, dynamic>.from(decoded);
    if (response.statusCode >= 400) {
      final code = body['code']?.toString();
      if (code == 'ACCOUNT_BANNED' &&
          invalidateSession &&
          _sessionToken != null) {
        unawaited(_clearSession());
        accountBanned.value++;
      } else if (code == 'REPORTING_SUSPENDED' && currentUser != null) {
        currentUser = {
          ...currentUser!,
          'standing': 'Suspended',
          'suspended_until': body['suspendedUntil'],
        };
        unawaited(_persistSession());
      } else if (code == 'ACCOUNT_NOT_VERIFIED' && currentUser != null) {
        currentUser = {
          ...currentUser!,
          'verification': body['verification']?.toString() ?? 'Not verified',
        };
        unawaited(_persistSession());
      }
      throw ApiException(
        body['error']?.toString() ?? 'Request failed (${response.statusCode})',
        code: code,
      );
    }
    return body;
  }

  static List<Map<String, dynamic>> _readList(
    Map<String, dynamic> body,
    String key,
  ) {
    final items = body[key];
    if (items is! List) {
      throw Exception('The server returned an invalid $key response.');
    }
    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final body = await _request(
      'POST',
      '/mobile/auth/login',
      body: {'email': email, 'password': password},
    );
    _sessionToken = body['token'] as String?;
    if (_sessionToken == null) {
      throw Exception('The server did not provide a sign-in session.');
    }
    currentUser = Map<String, dynamic>.from(body['user'] as Map);
    _sessionNotice = null;
    await _persistSession();
    return currentUser!;
  }

  static Future<void> logout({String? pushToken}) async {
    try {
      if (isSignedIn) {
        await _request(
          'POST',
          '/mobile/auth/logout',
          body: pushToken == null ? null : {'pushToken': pushToken},
          authenticated: true,
        );
      }
    } finally {
      await _clearSession();
    }
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String mobile,
    required String barangay,
    required String password,
  }) async {
    final body = await _request(
      'POST',
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'mobile': mobile,
        'barangay': barangay,
        'password': password,
      },
    );
    _sessionToken = body['token'] as String?;
    if (_sessionToken == null) {
      throw Exception('The server did not provide an account session.');
    }
    currentUser = Map<String, dynamic>.from(body['user'] as Map);
    await _persistSession();
    return currentUser!;
  }

  static Future<void> submitVerificationDocuments({
    required XFile idFrontImage,
    required XFile idBackImage,
    required XFile selfieImage,
    required String documentType,
  }) async {
    if (_sessionToken == null) {
      throw Exception(
        'Please sign in before submitting verification documents.',
      );
    }

    final requestToken = _sessionToken;
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$apiBaseUrl/mobile/verification-documents'),
          )
          ..headers['Authorization'] = 'Bearer $_sessionToken'
          ..fields['documentType'] = documentType
          ..files.add(
            await http.MultipartFile.fromPath(
              'idFrontImage',
              idFrontImage.path,
              contentType: MediaType(
                'image',
                _imageExtension(idFrontImage.path),
              ),
            ),
          )
          ..files.add(
            await http.MultipartFile.fromPath(
              'idBackImage',
              idBackImage.path,
              contentType: MediaType(
                'image',
                _imageExtension(idBackImage.path),
              ),
            ),
          )
          ..files.add(
            await http.MultipartFile.fromPath(
              'selfieImage',
              selfieImage.path,
              contentType: MediaType(
                'image',
                _imageExtension(selfieImage.path),
              ),
            ),
          );

    final response = await request.send().timeout(const Duration(seconds: 60));
    final body = await response.stream.bytesToString();
    if (response.statusCode != 401) {
      await _recordSessionActivity(requestToken);
    }
    if (response.statusCode == 401) {
      _sessionNotice = 'Your session has expired. For your security, please sign in again to continue.';
      await _clearSession();
      sessionExpired.value++;
    }
    if (response.statusCode >= 400) {
      final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
      throw Exception(
        decoded['error'] ?? 'Could not submit verification documents.',
      );
    }
    final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    final verification = decoded['verification'];
    if (currentUser != null && verification is String) {
      currentUser = {...currentUser!, 'verification': verification};
      await _persistSession();
    }
  }

  static String _imageExtension(String path) {
    final extension = path.split('.').last.toLowerCase();
    return {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpeg';
  }

  static Future<List<Map<String, dynamic>>> reports() async {
    if (!isSignedIn) return [];
    return _readList(
      await _request('GET', '/mobile/reports', authenticated: true),
      'reports',
    );
  }

  static Future<List<Map<String, dynamic>>> reportDiscussion(
    String reportId,
  ) async {
    final body = await _request(
      'GET',
      '/mobile/issues/${Uri.encodeComponent(reportId)}/discussion',
      authenticated: false,
    );
    final comments = body['comments'];
    if (comments is! List) {
      throw Exception('The server returned an invalid report discussion.');
    }
    return comments
        .map((comment) => Map<String, dynamic>.from(comment as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> postReportDiscussionReply({
    required String reportId,
    required String message,
  }) async {
    final body = await _request(
      'POST',
      '/mobile/issues/${Uri.encodeComponent(reportId)}/discussion',
      authenticated: true,
      body: {'body': message},
    );
    final comment = body['comment'];
    if (comment is! Map) {
      throw Exception('The server returned an invalid discussion reply.');
    }
    return Map<String, dynamic>.from(comment);
  }

  static Future<Map<String, dynamic>?> reportRating(String reportId) async {
    final body = await _request(
      'GET',
      '/mobile/issues/${Uri.encodeComponent(reportId)}/rating',
      authenticated: true,
    );
    final rating = body['rating'];
    if (rating == null) return null;
    if (rating is! Map) {
      throw Exception('The server returned an invalid report rating.');
    }
    return Map<String, dynamic>.from(rating);
  }

  static Future<Map<String, dynamic>> submitReportRating({
    required String reportId,
    required int rating,
    String? comment,
  }) async {
    final body = await _request(
      'POST',
      '/mobile/issues/${Uri.encodeComponent(reportId)}/rating',
      authenticated: true,
      body: {'rating': rating, 'comment': comment},
    );
    final savedRating = body['rating'];
    if (savedRating is! Map) {
      throw Exception('The server returned an invalid saved report rating.');
    }
    return Map<String, dynamic>.from(savedRating);
  }

  static Future<List<Map<String, dynamic>>> issues({
    bool verifiedOnly = false,
    bool homeUpdatesOnly = false,
  }) async {
    final queryParameters = <String, String>{};
    if (verifiedOnly) queryParameters['verified_only'] = 'true';
    if (homeUpdatesOnly) queryParameters['home_updates_only'] = 'true';
    final query = queryParameters.isEmpty
        ? ''
        : '?${Uri(queryParameters: queryParameters).query}';
    return _readList(await _request('GET', '/mobile/issues$query'), 'issues');
  }

  static Future<Map<String, dynamic>> overview() =>
      _request('GET', '/mobile/overview');

  static Future<void> checkServerConnection() async {
    try {
      await _request('GET', '/health');
    } on Exception {
      if (connectionIssue.value == null) rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> advisories() async =>
      _readList(await _request('GET', '/mobile/advisories'), 'advisories');

  static Future<Map<String, dynamic>> advisorySocial(String advisoryId) async {
    final body = await _request(
      'GET',
      '/mobile/advisories/${Uri.encodeComponent(advisoryId)}/social',
    );
    if (body['advisory'] is! Map || body['comments'] is! List) {
      throw Exception('The server returned an invalid advisory detail.');
    }
    return {
      ...body,
      'advisory': Map<String, dynamic>.from(body['advisory'] as Map),
      'comments': (body['comments'] as List)
          .map((comment) => Map<String, dynamic>.from(comment as Map))
          .toList(),
    };
  }

  static Future<Map<String, dynamic>> postAdvisoryComment({
    required String advisoryId,
    required String message,
    int? replyToCommentId,
  }) async {
    final body = await _request(
      'POST',
      '/mobile/advisories/${Uri.encodeComponent(advisoryId)}/comments',
      authenticated: true,
      body: {'body': message, 'reply_to_comment_id': replyToCommentId},
    );
    if (body['comment'] is! Map) {
      throw Exception('The server returned an invalid advisory comment.');
    }
    return Map<String, dynamic>.from(body['comment'] as Map);
  }

  static Future<({bool liked, int reactionCount})> toggleAdvisoryReaction(
    String advisoryId,
  ) async {
    final body = await _request(
      'POST',
      '/mobile/advisories/${Uri.encodeComponent(advisoryId)}/reaction',
      authenticated: true,
    );
    if (body['liked'] is! bool ||
        int.tryParse('${body['reaction_count']}') == null) {
      throw Exception('The server returned an invalid advisory reaction.');
    }
    return (
      liked: body['liked'] as bool,
      reactionCount: int.parse('${body['reaction_count']}'),
    );
  }

  static Future<List<Map<String, dynamic>>> notifications() async {
    if (!isSignedIn) return [];
    return _readList(
      await _request('GET', '/mobile/notifications', authenticated: true),
      'notifications',
    );
  }

  static Future<void> registerPushToken(String token) async {
    await _request(
      'POST',
      '/mobile/push-tokens',
      body: {'token': token, 'platform': 'android'},
      authenticated: true,
    );
  }

  static Future<void> unregisterPushToken(String token) async {
    await _request(
      'DELETE',
      '/mobile/push-tokens',
      body: {'token': token},
      authenticated: true,
    );
  }

  static Future<String> chatbotReply(List<Map<String, String>> messages) async {
    final response = await _request(
      'POST',
      '/mobile/chat',
      body: {'messages': messages},
      authenticated: true,
      timeout: const Duration(seconds: 90),
    );
    final reply = response['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw Exception(
        'The assistant returned an empty response. Please try again.',
      );
    }
    return reply.trim();
  }

  static Future<void> markNotificationRead(int notificationId) async {
    await _request(
      'PATCH',
      '/mobile/notifications/$notificationId/read',
      authenticated: true,
    );
    lastReadNotificationId = notificationId;
    notificationReadRevision.value++;
  }

  static Future<void> markAllNotificationsRead(
    Iterable<int> notificationIds,
  ) async {
    for (final notificationId in notificationIds) {
      await markNotificationRead(notificationId);
    }
  }

  static Future<Map<String, dynamic>> profile() async {
    final body = await _request('GET', '/mobile/profile', authenticated: true);
    currentUser = Map<String, dynamic>.from(body['user'] as Map);
    await _persistSession();
    return currentUser!;
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String mobile,
    required String barangay,
  }) async {
    final body = await _request(
      'PATCH',
      '/mobile/profile',
      authenticated: true,
      body: {'name': name, 'mobile': mobile, 'barangay': barangay},
    );
    currentUser = Map<String, dynamic>.from(body['user'] as Map);
    await _persistSession();
    return currentUser!;
  }

  static Future<Map<String, dynamic>> uploadProfilePhoto(XFile photo) async {
    if (_sessionToken == null) {
      throw Exception('Please sign in before changing your profile photo.');
    }
    final requestToken = _sessionToken!;
    final extension = photo.name.split('.').last.toLowerCase();
    final subtype = switch (photo.mimeType) {
      'image/jpeg' => 'jpeg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      null => switch (extension) {
        'jpg' || 'jpeg' => 'jpeg',
        'png' => 'png',
        'webp' => 'webp',
        _ => throw Exception('Choose a JPG, PNG, or WebP profile photo.'),
      },
      _ => throw Exception('Choose a JPG, PNG, or WebP profile photo.'),
    };
    final fileExtension = subtype == 'jpeg' ? 'jpg' : subtype;
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$apiBaseUrl/mobile/profile/photo'),
          )
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $requestToken'
          ..files.add(
            await http.MultipartFile.fromPath(
              'photo',
              photo.path,
              filename: 'profile-photo.$fileExtension',
              contentType: MediaType('image', subtype),
            ),
          );
    request.headers['Authorization'] = 'Bearer $requestToken';
    final client = httpClientFactory();
    try {
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 60));
      _markConnected();
      if (response.statusCode != 401) {
        await _recordSessionActivity(requestToken);
      }
      final body = _decodeResponse(response, invalidateSession: true);
      currentUser = Map<String, dynamic>.from(body['user'] as Map);
      await _persistSession();
      return currentUser!;
    } on SocketException {
      connectionIssue.value = 'Could not connect to InfraTrack. Check your internet connection and try again.';
      throw Exception(
        'Unable to reach the backend server. Check your internet connection and API server status.',
      );
    } on http.ClientException {
      connectionIssue.value = 'Could not connect to InfraTrack. Check your internet connection and try again.';
      throw Exception(
        'Unable to reach the backend server. Check your internet connection and API server status.',
      );
    } on TimeoutException {
      connectionIssue.value = 'The server took too long to respond. Check your connection and try again.';
      throw Exception('The upload took too long. Please try again.');
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> preferences() async {
    final body = await _request(
      'GET',
      '/mobile/preferences',
      authenticated: true,
    );
    return Map<String, dynamic>.from(body['preferences'] as Map);
  }

  static Future<Map<String, dynamic>> updatePreferences({
    required bool allowNotifications,
    required bool showLocationOnReports,
  }) async {
    final body = await _request(
      'PATCH',
      '/mobile/preferences',
      authenticated: true,
      body: {
        'allowNotifications': allowNotifications,
        'showLocationOnReports': showLocationOnReports,
      },
    );
    return Map<String, dynamic>.from(body['preferences'] as Map);
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _request(
      'PATCH',
      '/mobile/profile/password',
      authenticated: true,
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  static Future<Map<String, dynamic>> createReport({
    required String title,
    required String description,
    required String category,
    required String location,
    required String severity,
    String? aiSeverity,
    String? aiAnalysis,
    double? latitude,
    double? longitude,
    String? mediaUrl,
    String? mediaType,
  }) async {
    _requireVerifiedAccount();
    final body = await _request(
      'POST',
      '/mobile/reports',
      authenticated: true,
      body: {
        'title': title,
        'description': description,
        'category': category,
        'location': location,
        'severity': severity,
        'aiSeverity': aiSeverity,
        'aiAnalysis': aiAnalysis,
        'latitude': latitude,
        'longitude': longitude,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
      },
    );
    return Map<String, dynamic>.from(body['report'] as Map);
  }

  static Future<ReportSeverityAssessment> assessReportSeverity({
    required String description,
    required String category,
    File? evidence,
    bool isVideo = false,
  }) async {
    if (_sessionToken == null) {
      throw Exception('Please sign in before assessing report severity.');
    }
    _requireVerifiedAccount();
    final requestToken = _sessionToken;
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$apiBaseUrl/mobile/reports/severity'),
          )
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $requestToken'
          ..fields['description'] = description
          ..fields['category'] = category;
    if (evidence != null) {
      request.fields['mediaType'] = isVideo ? 'video' : 'photo';
      request.files.add(
        await http.MultipartFile.fromPath(
          'evidence',
          evidence.path,
          filename: isVideo ? 'severity-evidence.mp4' : 'severity-evidence.jpg',
          contentType: isVideo
              ? MediaType('video', 'mp4')
              : MediaType('image', 'jpeg'),
        ),
      );
    }

    final client = httpClientFactory();
    try {
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 45));
      _markConnected();
      if (response.statusCode != 401) {
        await _recordSessionActivity(requestToken);
      }
      final body = _decodeResponse(response, invalidateSession: true);
      final severity = body['severity'];
      final analysis = body['analysis'];
      if (severity is! String ||
          !const ['Low', 'Medium', 'High', 'Critical'].contains(severity) ||
          analysis is! String ||
          analysis.trim().isEmpty) {
        throw const FormatException(
          'The AI assessment service returned an invalid result.',
        );
      }
      return ReportSeverityAssessment(severity: severity, analysis: analysis);
    } on SocketException {
      connectionIssue.value = 'Could not connect to InfraTrack. Check your internet connection and try again.';
      rethrow;
    } on http.ClientException {
      connectionIssue.value = 'Could not connect to InfraTrack. Check your internet connection and try again.';
      rethrow;
    } on TimeoutException {
      connectionIssue.value = 'The server took too long to respond. Check your connection and try again.';
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<String> uploadMedia(File file, {required bool isVideo}) async {
    if (_sessionToken == null) {
      throw Exception('Please sign in before uploading report media.');
    }
    _requireVerifiedAccount();
    final request =
        http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/uploads'))
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $_sessionToken'
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              file.path,
              filename: isVideo ? 'report-video.mp4' : 'report-photo.jpg',
              contentType: isVideo
                  ? MediaType('video', 'mp4')
                  : MediaType('image', 'jpeg'),
            ),
          );
    final client = httpClientFactory();
    try {
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 60));
      _markConnected();
      return _decodeResponse(response, invalidateSession: true)['url']
          as String;
    } on SocketException {
      connectionIssue.value = 'Could not connect to InfraTrack. Check your internet connection and try again.';
      throw Exception(
        'Unable to reach the backend server. Check your internet connection and API server status.',
      );
    } on http.ClientException {
      connectionIssue.value = 'Could not connect to InfraTrack. Check your internet connection and try again.';
      throw Exception(
        'Unable to reach the backend server. Check your internet connection and API server status.',
      );
    } on TimeoutException {
      connectionIssue.value = 'The server took too long to respond. Check your connection and try again.';
      throw Exception('The upload took too long. Please try again.');
    } finally {
      client.close();
    }
  }
}
