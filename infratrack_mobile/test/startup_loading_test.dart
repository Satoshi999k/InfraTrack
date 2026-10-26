import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup shows concise session status before opening login', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: AppLoadingPage()));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('InfraTrack'), findsOneWidget);
    expect(find.text('Restoring your session…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(AppLoadingPage), findsOneWidget);
    final mascotFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/chatbot_character/thinking_animation/trako_loading.png',
    );
    expect(mascotFinder, findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
          return false;
        }
        final image = (widget.decoration as BoxDecoration).image?.image;
        return image is AssetImage &&
            image.assetName ==
                'assets/chatbot_character/thinking_animation/loading_background.png';
      }),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/chatbot_character/chatbot_face/logo (2).png',
      ),
      findsNothing,
    );
    final mascotStartY = tester.getTopLeft(mascotFinder).dy;
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getTopLeft(mascotFinder).dy, isNot(mascotStartY));

    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.byType(AppLoadingPage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.byType(AppLoadingPage), findsNothing);
  });

  testWidgets('startup supports reduced-motion preferences', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const AppLoadingPage(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Restoring your session…'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.byType(AppLoadingPage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(AppLoadingPage), findsNothing);
  });
}
