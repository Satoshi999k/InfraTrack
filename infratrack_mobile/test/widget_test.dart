import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:infatrack/api_service.dart';
import 'package:infatrack/main.dart';

void main() {
  test('InfraTrack app shell is constructible', () {
    expect(const InfraTrackApp(), isA<InfraTrackApp>());
    expect(const MainShell(), isA<MainShell>());
  });

  test('Selfie preview height is large enough for the camera view', () {
    expect(SelfieVerificationPage.previewHeight, greaterThan(350.0));
  });

  test(
    'Liveness challenge accepts a real head turn but rejects a static face',
    () {
      expect(
        LivenessChallengeState.isTurnSatisfied(headYaw: -28, turnLeft: true),
        isTrue,
      );
      expect(
        LivenessChallengeState.isTurnSatisfied(headYaw: 24, turnLeft: false),
        isTrue,
      );
      expect(
        LivenessChallengeState.isTurnSatisfied(headYaw: 0, turnLeft: true),
        isFalse,
      );
      expect(
        LivenessChallengeState.isTurnSatisfied(headYaw: 8, turnLeft: false),
        isFalse,
      );
    },
  );

  test(
    'thinking animation GIF is bundled as an animated image asset',
    () async {
      final gif = await rootBundle.load(
        'assets/chatbot_character/thinking_animation/infratrack_mascot_hand_thinking.gif',
      );

      expect(
        String.fromCharCodes([
          gif.getUint8(0),
          gif.getUint8(1),
          gif.getUint8(2),
        ]),
        'GIF',
      );
    },
  );

  testWidgets('notification header and filters stay in a pinned sliver', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NotificationsPage()));
    await tester.pumpAndSettle();

    final header = tester.widget<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    expect(header.pinned, isTrue);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Report updates'), findsOneWidget);
    expect(find.text('City updates'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    final filters = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(filters, hasLength(4));
    expect(filters.every((chip) => chip.avatar is Icon), isTrue);
  });

  testWidgets('my reports header stays pinned and filters show status icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MyReportsPage()));
    await tester.pumpAndSettle();

    final stickyHeader = tester.widget<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    expect(stickyHeader.pinned, isTrue);

    final horizontalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScroll, findsOneWidget);

    final filterChips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(filterChips, hasLength(6));
    expect(filterChips.every((chip) => chip.avatar is Icon), isTrue);

    final allFilter = find.widgetWithText(FilterChip, 'All');
    final resolvedFilter = find.widgetWithText(FilterChip, 'Resolved');
    expect(
      tester.getTopLeft(allFilter).dy,
      tester.getTopLeft(resolvedFilter).dy,
    );

    await tester.drag(horizontalScroll, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(resolvedFilter);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(resolvedFilter).selected, isTrue);
  });

  testWidgets('connection failure replaces app content with the mascot state', (
    WidgetTester tester,
  ) async {
    ApiService.connectionIssue.value = 'Could not connect to InfraTrack. Check your internet connection and try again.';
    await tester.pumpWidget(const InfraTrackApp());
    await tester.pump();

    expect(find.text('We can’t reach InfraTrack'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    ApiService.connectionIssue.value = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shared notifier presents a branded success notice', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showInfraNotice(
                    context,
                    'Biometric sign-in is enabled.',
                    kind: InfraNoticeKind.success,
                  ),
                  child: const Text('Show success'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show success'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Biometric sign-in is enabled.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byTooltip('Dismiss notification'), findsOneWidget);
  });

  testWidgets('shared notifier presents a branded error notice', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showInfraNotice(
                context,
                'Could not save your changes.',
                kind: InfraNoticeKind.error,
              ),
              child: const Text('Show error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show error'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Could not save your changes.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('chat intro keeps its thumbs-up mascot pose', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChatbotPage()));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/chatbot_character/chatbot_face/thumbs_up.png',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/chatbot_character/chatbot_face/profile.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('chat composer grows to multiple lines for longer messages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChatbotPage()));

    final composerFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Ask the assistant...',
    );
    final composer = tester.widget<TextField>(composerFinder);
    expect(composer.minLines, 1);
    expect(composer.maxLines, 5);
    expect(composer.keyboardType, TextInputType.multiline);
    expect(find.byTooltip('Send message'), findsOneWidget);

    final initialHeight = tester.getSize(composerFinder).height;
    await tester.enterText(composerFinder, 'One line\nTwo lines\nThree lines');
    await tester.pumpAndSettle();
    expect(tester.getSize(composerFinder).height, greaterThan(initialHeight));
  });
}
