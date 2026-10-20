import 'package:flutter/material.dart';
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
  });

  testWidgets('my report filters stay in one horizontally scrollable row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MyReportsPage()));
    await tester.pumpAndSettle();

    final horizontalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScroll, findsOneWidget);

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
}
