import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:infatrack/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'profile photo upload uses the active bearer session without signing out',
    () async {
      SharedPreferences.setMockInitialValues({});
      final originalClientFactory = ApiService.httpClientFactory;
      final sessionExpiryCount = ApiService.sessionExpired.value;
      final receivedAuthorizationHeaders = <String?>[];
      ApiService.httpClientFactory = () => MockClient((request) async {
        if (request.url.path.endsWith('/mobile/auth/login')) {
          return http.Response(
            jsonEncode({
              'token': 'test-session-token',
              'user': {'id': 42, 'name': 'Test Resident'},
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/mobile/profile/photo')) {
          receivedAuthorizationHeaders.add(request.headers['Authorization']);
          return http.Response(
            jsonEncode({
              'user': {
                'id': 42,
                'name': 'Test Resident',
                'avatar_url': 'https://example.test/profile.jpg',
              },
            }),
            200,
          );
        }

        return http.Response('Not found', 404);
      });

      final tempDirectory = await Directory.systemTemp.createTemp(
        'infratrack-profile-photo-test-',
      );
      try {
        await ApiService.login('resident@example.test', 'test-password');
        final photoFile = File('${tempDirectory.path}\\profile.jpg');
        await photoFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);

        final updatedUser = await ApiService.uploadProfilePhoto(
          XFile(photoFile.path, name: 'profile.jpg', mimeType: 'image/jpeg'),
        );

        expect(receivedAuthorizationHeaders, ['Bearer test-session-token']);
        expect(updatedUser['avatar_url'], 'https://example.test/profile.jpg');
        expect(ApiService.sessionExpired.value, sessionExpiryCount);
      } finally {
        ApiService.httpClientFactory = originalClientFactory;
        await tempDirectory.delete(recursive: true);
      }
    },
  );
}
