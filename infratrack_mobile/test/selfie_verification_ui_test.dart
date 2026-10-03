import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:infatrack/main.dart';

void main() {
  testWidgets(
    'selfie verification does not require a manual start button',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SelfieVerificationPage(idImage: XFile('test.jpg')),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Start liveness check'), findsNothing);
      expect(find.text('Retake selfie'), findsNothing);
    },
  );
}
