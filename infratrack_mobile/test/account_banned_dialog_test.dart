import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'account restriction dialog is compact and keeps sign-out action',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      var continued = false;

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => AccountBannedDialog(
                        onContinue: () {
                          continued = true;
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    child: const Text('Open restriction dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open restriction dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Account access restricted'), findsOneWidget);
        expect(find.text('Sign out'), findsOneWidget);
        expect(
          find.textContaining('contact Mati City support'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.gpp_bad_outlined), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('accountBannedDialogSurface')))
              .height,
          lessThan(
            tester.view.physicalSize.height /
                    tester.view.devicePixelRatio *
                    .82 +
                1,
          ),
        );

        await tester.ensureVisible(find.text('Sign out'));
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        expect(continued, isTrue);
        expect(find.byType(Dialog), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );
}
