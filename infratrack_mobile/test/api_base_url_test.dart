import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/api_service.dart';

void main() {
  test('native debug builds use the reachable production API by default', () {
    if (kIsWeb) return;

    expect(apiBaseUrl, 'https://infratrack-3a8u.onrender.com/api');
  });
}
