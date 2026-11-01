import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/api_service.dart';
import 'package:infatrack/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('expired restored session shows a persistent sign-in notice', (
    WidgetTester tester,
  ) async {
    ApiService.sessionTokenStore = _MemorySessionTokenStore(
      'expired-session-test-token',
    );
    final lastOpened = DateTime.now()
        .subtract(const Duration(hours: 9))
        .millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'session_user': jsonEncode({'id': 42, 'name': 'Test Resident'}),
      'session_last_opened': lastOpened,
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    try {
      await tester.pumpWidget(const MaterialApp(home: AppLoadingPage()));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );

      expect(find.byType(AppLoadingPage), findsNothing);
      expect(find.text('Your session has ended'), findsOneWidget);
      expect(find.textContaining('8 hours of inactivity'), findsOneWidget);
      expect(
        find.textContaining('Your reports and account details are safe'),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await ApiService.signOutForExpiredSession();
    }
  });
}

class _MemorySessionTokenStore implements ApiSessionTokenStore {
  _MemorySessionTokenStore(this.token);

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
