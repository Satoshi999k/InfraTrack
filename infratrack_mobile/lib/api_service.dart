import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_configuredApiBaseUrl.isNotEmpty) return _configuredApiBaseUrl;
  // Web preview uses the host machine's localhost.
  // Real devices must target the machine running the Node.js API on the same LAN.
  // For Android emulator, override with:
  // flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001/api
  if (kIsWeb) return 'http://localhost:3001/api';
  return 'http://10.230.167.43:3001/api';
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
  static Map<String, dynamic>? currentUser;

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw Exception(body['error'] ?? 'Sign in failed');
      }
      currentUser = Map<String, dynamic>.from(body['user'] as Map);
      return currentUser!;
    } on http.ClientException {
      throw Exception(
        'Unable to reach the backend server. Ensure the app is using the correct PC IP on your network.',
      );
    }
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String mobile,
    required String barangay,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'mobile': mobile,
          'barangay': barangay,
          'password': password,
        }),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw Exception(body['error'] ?? 'Registration failed');
      }
      currentUser = Map<String, dynamic>.from(body['user'] as Map);
      return currentUser!;
    } on http.ClientException {
      throw Exception(
        'Unable to reach the backend server. Ensure the app is using the correct PC IP on your network.',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> reports() async {
    final userId = currentUser?['id'];
    final uri = Uri.parse(
      '$apiBaseUrl/reports${userId == null ? '' : '?userId=$userId'}',
    );
    final response = await http.get(uri);
    if (response.statusCode >= 400) {
      throw Exception('Could not load reports');
    }
    return (jsonDecode(response.body)['reports'] as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> issues() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/issues'));
    if (response.statusCode >= 400) {
      throw Exception('Could not load infrastructure issues');
    }
    return (jsonDecode(response.body)['issues'] as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> overview() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/overview'));
    if (response.statusCode >= 400) {
      throw Exception('Could not load dashboard overview');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> advisories() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/advisories'));
    if (response.statusCode >= 400) {
      throw Exception('Could not load public advisories');
    }
    return (jsonDecode(response.body)['advisories'] as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> createReport({
    required String title,
    required String description,
    required String category,
    required String location,
    double? latitude,
    double? longitude,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/reports'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'reporterId': currentUser?['id'],
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(body['error'] ?? 'Could not submit report');
    }
    return Map<String, dynamic>.from(body['report'] as Map);
  }

  static Future<String> uploadMedia(File file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBaseUrl/uploads'),
    )..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    final body = jsonDecode(
      await response.stream.bytesToString(),
    ) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(body['error'] ?? 'Could not upload media');
    }
    return body['url'] as String;
  }
}
