import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates legacy session tokens to secure storage', () async {
    final tokenStore = _MemorySessionTokenStore();
    ApiService.sessionTokenStore = tokenStore;
    SharedPreferences.setMockInitialValues({
      'session_token': 'legacy-session-token',
      'session_user': jsonEncode({'id': 42, 'name': 'Test Resident'}),
      'session_last_opened': DateTime.now().millisecondsSinceEpoch,
    });

    await ApiService.restoreSession();

    final preferences = await SharedPreferences.getInstance();
    expect(tokenStore.token, 'legacy-session-token');
    expect(preferences.getString('session_token'), isNull);
    expect(ApiService.isSignedIn, isTrue);

    await ApiService.signOutForExpiredSession();
  });
}

class _MemorySessionTokenStore implements ApiSessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> delete() async {
    token = null;
  }
}
