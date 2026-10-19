import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:infatrack/main.dart';

void main() {
  testWidgets('account-created dialog confirms and offers sign in', (
    WidgetTester tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountCreatedDialog(onOk: () => continued = true),
        ),
      ),
    );

    expect(find.text('Your account is ready!'), findsOneWidget);
    expect(find.text('VERIFICATION SUBMITTED'), findsOneWidget);
    expect(find.text('OK, go to sign in'), findsOneWidget);

    await tester.tap(find.text('OK, go to sign in'));
    expect(continued, isTrue);
  });

  testWidgets('selfie verification does not require a manual start button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SelfieVerificationPage(idImage: XFile('test.jpg'))),
    );

    await tester.pumpAndSettle();

    expect(find.text('Start liveness check'), findsNothing);
    expect(find.text('Retake selfie'), findsNothing);
  });
}
