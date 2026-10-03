import 'package:flutter_test/flutter_test.dart';

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
}
